console.log('OpenAI Reword content.js loaded!');
let lastChange = null;

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === 'hotkey-pressed') {
    const sel = window.getSelection();
    const selectedText = sel && sel.toString();
    if (selectedText && selectedText.trim().length > 0) {
      chrome.runtime.sendMessage({
        action: "sendOpenAIQuery",
        selectedText
      });
    }
    return;
  }
  if (msg.action === 'replaceSelection') {
    replaceSelectedText(msg.replacement, msg.showPopup, sendResponse);
    return true;
  }
  if (msg.action === 'revertReplacement') {
    revertLastChange();
  }
  if (msg.action === 'tryAgain') {
    triggerTryAgain();
  }
});

function replaceSelectedText(newText, showPopup, cb) {
  let success = false;

  // 1. Always attempt to copy to clipboard
  console.log('Attempting to copy:', newText);
  chrome.runtime.sendMessage({ action: "copyToClipboard", text: newText }).then(() => {
    console.log('Sent copyToClipboard message to background');
    // You can notify in the popup if desired, rather than an alert.
    // alert("AI rewrite copied! Paste (Cmd+V/Ctrl+V) to replace if needed.");
  }, (err) => {
    alert("Failed to copy reworded text to clipboard.");
  });

  // 2. Attempt native replacement with window.getSelection()
  try {
    const selection = window.getSelection();
    if (selection && selection.rangeCount) {
      const range = selection.getRangeAt(0);
      const original = range.toString();

      // Save state for revert
      lastChange = {
        range: range.cloneRange(),
        original,
        newText
      };

      // Try to replace
      range.deleteContents();
      const replacementNode = document.createTextNode(newText);
      range.insertNode(replacementNode);

      // Reselect replaced text
      selection.removeAllRanges();
      const newRange = document.createRange();
      newRange.selectNode(replacementNode);
      selection.addRange(newRange);

      // Get position for popup
      const rect = newRange.getBoundingClientRect();
      if (showPopup) {
        showResultPopup(newText, rect, true); // True flag: copied
      }

      success = true;
      if(cb) cb({success: true});
      return; // early exit
    }
  } catch (e) {
    success = false;
  }

  // 3. If replacement failed, show persistent notification
  if (!success && showPopup) {
    showResultPopup(newText, {left: window.innerWidth/2, bottom: window.innerHeight/2}, true);
  }
  if(cb) cb({success: success});
}

function revertLastChange() {
  if (lastChange) {
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(lastChange.range);
    replaceSelectedText(lastChange.original, false);
    removeResultPopup();
    lastChange = null;
  }
}

function removeResultPopup() {
  const popup = document.getElementById('__openai_result_popup');
  if (popup) popup.remove();
}

function showResultPopup(aiText, rect, copied) {
  removeResultPopup();
  let popup = document.createElement('div');
  popup.id = '__openai_result_popup';
  popup.style.position = 'fixed';
  popup.style.zIndex = 999999999;
  popup.style.left = `${Math.max(rect.left + window.scrollX - 20, 20)}px`;
  popup.style.top = `${rect.bottom + window.scrollY + 8}px`;
  popup.style.background = 'white';
  popup.style.border = '1px solid #aaa';
  popup.style.borderRadius = '6px';
  popup.style.padding = '10px';
  popup.style.boxShadow = '0 2px 12px rgba(0,0,0,0.15)';
  popup.style.maxWidth = '350px';
  popup.style.fontFamily = 'inherit';
  popup.innerHTML = `
    <div style="font-size: 0.95em; margin-bottom: 8px;">
      <strong>AI reworded:</strong><br>
      <span>${escapeHtml(aiText)}</span>
      ${copied ? `<div style="color:green; margin-top:7px; font-size:0.93em;">
        Copied to clipboard. Paste (Ctrl+V / Cmd+V) if needed.
      </div>` : ""}
    </div>
    <button id="or_revert" style="margin-right:7px;">Revert</button>
    <button id="or_tryagain">Try Again</button>
    <button id="or_close" style="float:right;">×</button>
  `;
  document.body.appendChild(popup);

  popup.querySelector('#or_revert').onclick = () => {
    chrome.runtime.sendMessage({ action: 'revertReplacement' });
  };
  popup.querySelector('#or_tryagain').onclick = () => {
    chrome.runtime.sendMessage({ action: 'tryAgain' });
    removeResultPopup();
  };
  popup.querySelector('#or_close').onclick = () => removeResultPopup();
}

function escapeHtml(unsafe) {
  return unsafe.replace(/[&<"'>]/g, (m) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[m]));
}

function triggerTryAgain() {
  if (lastChange && lastChange.range) {
    let selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(lastChange.range);
    chrome.runtime.sendMessage({
      action: "sendOpenAIQuery",
      selectedText: lastChange.original
    });
  }
}