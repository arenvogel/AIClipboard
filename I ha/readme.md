# OpenAI Reword & Replace — Chrome Extension

This Chrome extension uses OpenAI to reword highlighted text on most webpages with your own custom prompt and API key.

---

## 1. Loading the Unpacked Extension

1. Download or assemble all extension files (`manifest.json`, `background.js`, `content.js`, `options.html`, etc.) in a folder.
2. Open Chrome and go to `chrome://extensions`
3. Enable **Developer mode** (top right).
4. Click **Load unpacked**.
5. Select your extension folder. The extension will appear in your list.

---

## 2. Fill in the Options Page

1. In the extensions list, find **OpenAI Reword & Replace** and click **Details**.
2. Click **Extension options** to open the settings page.
3. Enter your OpenAI API Key (`sk-...`).
4. Enter your desired prompt. (Tip: Use a colon at the end of the prompt so it is clear where your prompt ends and the highlighted text begins)
   - Example: `Reword this text for clarity, it will be used in a Product Requirements Document. If a statement is written as a shall statement, the revised statement should maintain that format:`
5. Click **Save**.

---

## 3. Create and Assign a Hotkey

1. Open [chrome://extensions/shortcuts](chrome://extensions/shortcuts) in Chrome.
2. Find your extension's shortcut ("Reword highlighted text with OpenAI").
3. Click the empty field and press your preferred key combo (e.g. `Ctrl+Alt+R` on Windows/Linux or `Command+Ctrl+R` on Mac).
   - **Note:** Chrome does *not* automatically set a key for unpacked extensions; you must assign it yourself.

---

## 4. How to Use the Extension

### **A. Right-Click Menu**
- Highlight text on any webpage.
- Right-click, choose **Reword with OpenAI**.
- The reworded text will (if possible) replace the original, and a popup will appear with options to revert, try again, or close.

### **B. Using a Hotkey**
- Highlight text on any webpage.
- Press your assigned hotkey.
- The AI will reword the text as above.

### **C. Copy/Paste Fallback**
- If in-place replacing fails (on pages like Confluence), the rewritten text will always be copied to your clipboard.
- Simply paste (`Ctrl+V` or `Cmd+V`) the AI output where you want it.

---

## 5. Disclaimer — Hotkeys and Confluence Limitations

- **Keyboard shortcuts may not work in Confluence and some rich-text editors.**
   - These editors intercept or block most keyboard shortcuts before Chrome or your extension sees them.
- In Confluence’s main editor, the extension may **not be able to replace the text in place** due to technical limitations.
- **However, the reworded text will ALWAYS be copied to your clipboard.**
  You can simply paste (`Ctrl+V` or `Cmd+V`) the updated text into Confluence or any other editor.

---

## Support

If you have issues or suggestions, open an issue or discussion on this project’s repository.