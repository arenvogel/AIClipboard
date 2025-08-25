// Context menu creation (as before)
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "reword-selection",
    title: "Reword with OpenAI",
    contexts: ["selection"]
  });
});

// Context menu click handler (as before)
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "reword-selection" && info.selectionText) {
    chrome.storage.local.get(['apiKey', 'prompt'], ({ apiKey, prompt }) => {
      if (!apiKey || !prompt) {
        chrome.scripting.executeScript({
          target: { tabId: tab.id },
          func: () => alert('Please set your OpenAI API key and prompt in the extension options.')
        });
        return;
      }
      sendOpenAIQuery(tab.id, info.selectionText, apiKey, prompt);
    });
  }
});

// Hotkey support: Send a broadcast to all frames on the tab
chrome.commands.onCommand.addListener((command, tab) => {
  if (command === "reword-selection") {
    chrome.tabs.sendMessage(tab.id, { action: "hotkey-pressed" });
  }
});

// Listen for actual OpenAI API requests from content scripts (for hotkey)
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === "copyToClipboard" && msg.text) {
    console.log('Background received copyToClipboard for:', msg.text);
    copyTextToClipboard(msg.text);
  }
  if (msg.action === 'sendOpenAIQuery') {
    chrome.storage.local.get(['apiKey', 'prompt'], ({ apiKey, prompt }) => {
      if (!apiKey || !prompt) return;
      sendOpenAIQuery(sender.tab.id, msg.selectedText, apiKey, prompt);
    });
  }
});

// Helper for OpenAI API call
async function sendOpenAIQuery(tabId, selectedText, apiKey, prompt) {
  const fullPrompt = prompt.includes('{text}')
    ? prompt.replace('{text}', selectedText)
    : `${prompt}\n\n${selectedText}`;
  let completion;
  try {
    completion = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-3.5-turbo",
        messages: [{ role: "user", content: fullPrompt }]
      })
    }).then(r => r.json());
  } catch (err) {
    completion = { error: { message: String(err) } };
  }
  let reply = (completion.choices && completion.choices[0] && completion.choices[0].message.content) ?
    completion.choices[0].message.content.trim() :
    (completion.error && completion.error.message) ? ("ERROR: " + completion.error.message) : "Error: No response.";
  // Broadcast the result to all frames; only the one that made the request will act.
  chrome.tabs.sendMessage(tabId, {
    action: "replaceSelection",
    replacement: reply,
    showPopup: false
  });
}


// Helper using the Chrome Scripting API
// This makes the background execute clipboard-write code in the active tab
function copyTextToClipboard(text) {
  console.log('About to inject clipboard script with:', text);
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (tabs[0]) {
      chrome.scripting.executeScript({
        target: { tabId: tabs[0].id },
        func: (text) => {
          navigator.clipboard.writeText(text);
          console.log('Injected script attempting navigator.clipboard.writeText');
        },
        args: [text]
      });
    }
  });
}