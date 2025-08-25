document.getElementById('save').addEventListener('click', () => {
  chrome.storage.local.set({
    apiKey: document.getElementById('apiKey').value,
    prompt: document.getElementById('prompt').value
  }, () => {
    document.getElementById('status').textContent = 'Saved!';
    setTimeout(() => (document.getElementById('status').textContent = ''), 2000);
  });
});

window.onload = () => {
  chrome.storage.local.get(['apiKey', 'prompt'], (result) => {
    if (result.apiKey) document.getElementById('apiKey').value = result.apiKey;
    if (result.prompt) document.getElementById('prompt').value = result.prompt;
  });
};