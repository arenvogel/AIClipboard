
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel<ContentView>!
  private var aiDefineWindowController = AIDefineWindowController()

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.action = #selector(performStatusItemClick)
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    statusItem.button?.target = self
    return statusItem
  }()

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      SPUUpdater(hostBundle: Bundle.main,
                 applicationBundle: Bundle.main,
                 userDriver: SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil),
                 delegate: nil)
      .automaticallyChecksForUpdates = false
    }
    #endif

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    Clipboard.shared.onNewCopy { History.shared.add($0) }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        statusItem.button?.image = value.image
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    setupAIRewordingHotkeys()
    setupAIDefineHotkey()
    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy",
      statusBarButton: statusItem.button,
      onClose: { AppState.shared.popup.reset() }
    ) {
      ContentView()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    if Defaults[.clearOnQuit] {
      AppState.shared.history.clear()
    }
  }

  private func migrateUserDefaults() {
    if Defaults[.migrations]["2024-07-01-version-2"] != true {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")

      Defaults[.migrations]["2024-07-01-version-2"] = true
    }

    // The following defaults are not used in Maccy 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @objc
  private func performStatusItemClick() {
    if let event = NSApp.currentEvent {
      let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

      if modifierFlags.contains(.option) {
        Defaults[.ignoreEvents].toggle()

        if modifierFlags.contains(.shift) {
          Defaults[.ignoreOnlyNextEvent] = Defaults[.ignoreEvents]
        }

        return
      }
    }

    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }

  private func setupAIDefineHotkey() {
    print("DEBUG: Setting up AI Define hotkey (.aiDefine)")
    KeyboardShortcuts.onKeyDown(for: .aiDefine) { [weak self] in
      print("DEBUG: AI Define hotkey pressed! Starting handler...")
      Task { @MainActor in
        self?.handleAIDefine()
      }
    }
    print("DEBUG: AI Define hotkey setup complete")
  }
  
  @MainActor
  private func handleAIDefine() {
    print("DEBUG: handleAIDefine() called")
    
    // Check clipboard history
    let historyItems = History.shared.all
    print("DEBUG: History has \(historyItems.count) items")
    
    guard let mostRecentItem = historyItems.first else {
      print("DEBUG: No clipboard items found for AI Define")
      return
    }
    
    print("DEBUG: Most recent clipboard item: '\(mostRecentItem.text.prefix(50))'...")
    
    // Check prompt configuration
    let prompt = Defaults[.aiDefinePrompt]
    print("DEBUG: AI Define prompt from defaults: '\(prompt)'")
    guard !prompt.isEmpty else {
      print("DEBUG: AI Define prompt is empty")
      return
    }
    
    // Check API key configuration
    let apiKey = Defaults[.azureOpenAIApiKey]
    print("DEBUG: API Key configured: \(apiKey.isEmpty ? "No" : "Yes (\(apiKey.count) characters)")")
    guard !apiKey.isEmpty else {
      print("DEBUG: OpenAI API key is empty or not configured")
      return
    }
    
    let termToDefine = mostRecentItem.text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    print("DEBUG: Starting AI define request")
    print("DEBUG: Term to define: '\(termToDefine)'")
    print("DEBUG: Prompt: '\(prompt)'")
    print("DEBUG: API Key exists: \(apiKey.count > 0 ? "Yes (\(String(apiKey.prefix(8)))...)" : "No")")
    
    // Send request to OpenAI
    Task {
      do {
        print("DEBUG: Sending OpenAI request...")
        let definition = try await sendOpenAIRequest(prompt: prompt, text: termToDefine, apiKey: apiKey)
        print("DEBUG: OpenAI response received (length: \(definition.count) characters)")
        
        // Show the definition in a popup window
        await MainActor.run {
          print("DEBUG: Showing definition window...")
          aiDefineWindowController.show(definition: definition, term: termToDefine)
          print("DEBUG: Definition window show() method called")
        }
        print("DEBUG: Successfully displayed definition window")
      } catch {
        print("DEBUG: OpenAI API error in AI Define: \(error)")
      }
    }
  }
  
  private func sendOpenAIRequest(prompt: String, text: String, apiKey: String) async throws -> String {
    print("DEBUG: sendOpenAIRequest called")
    print("DEBUG: Prompt: '\(prompt)'")
    print("DEBUG: Text: '\(text)'")
    print("DEBUG: API Key length: \(apiKey.count)")
    
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    print("DEBUG: URL: \(url)")
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody: [String: Any] = [
      "model": "gpt-4o",
      "messages": [
        [
          "role": "user",
          "content": "\(prompt) \(text)"
        ]
      ],
      "max_tokens": 1000,
      "temperature": 0.7
    ]
    
    print("DEBUG: Request body: \(requestBody)")
    
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
      print("DEBUG: Request body serialized successfully")
    } catch {
      print("DEBUG: Failed to serialize request body: \(error)")
      throw error
    }
    
    print("DEBUG: Sending HTTP request...")
    let (data, response) = try await URLSession.shared.data(for: request)
    
    print("DEBUG: HTTP response received")
    print("DEBUG: Response data length: \(data.count) bytes")
    
    guard let httpResponse = response as? HTTPURLResponse else {
      print("DEBUG: Invalid HTTP response type")
      throw OpenAIError.invalidResponse
    }
    
    print("DEBUG: HTTP status code: \(httpResponse.statusCode)")
    print("DEBUG: HTTP response headers: \(httpResponse.allHeaderFields)")
    
    if httpResponse.statusCode != 200 {
      print("DEBUG: Non-200 status code received")
      if let responseString = String(data: data, encoding: .utf8) {
        print("DEBUG: Response body: \(responseString)")
      }
      throw OpenAIError.invalidResponse
    }
    
    print("DEBUG: Parsing JSON response...")
    let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    print("DEBUG: JSON response parsed: \(jsonResponse ?? [:])")
    
    guard let choices = jsonResponse?["choices"] as? [[String: Any]],
          let firstChoice = choices.first,
          let message = firstChoice["message"] as? [String: Any],
          let content = message["content"] as? String else {
      print("DEBUG: Invalid response format - missing expected fields")
      throw OpenAIError.invalidResponseFormat
    }
    
    print("DEBUG: Successfully extracted content from response")
    print("DEBUG: Content length: \(content.count) characters")
    print("DEBUG: Content preview: \(content.prefix(100))...")
    
    return content.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  // MARK: - AI Rewording Functionality
  
  private func setupAIRewordingHotkeys() {
    print("DEBUG: Setting up AI Rewording hotkeys")
    
    // Setup AI Rewording 1 (Cmd+Opt+1)
    KeyboardShortcuts.onKeyDown(for: .aiRewording1) { [weak self] in
      print("DEBUG: AI Rewording 1 hotkey pressed!")
      Task { @MainActor in
        self?.handleAIRewording(promptKey: .aiRewordingPrompt1, promptNumber: 1)
      }
    }
    
    // Setup AI Rewording 2 (Cmd+Opt+2)
    KeyboardShortcuts.onKeyDown(for: .aiRewording2) { [weak self] in
      print("DEBUG: AI Rewording 2 hotkey pressed!")
      Task { @MainActor in
        self?.handleAIRewording(promptKey: .aiRewordingPrompt2, promptNumber: 2)
      }
    }
    
    // Setup AI Rewording 3 (Cmd+Opt+3)
    KeyboardShortcuts.onKeyDown(for: .aiRewording3) { [weak self] in
      print("DEBUG: AI Rewording 3 hotkey pressed!")
      Task { @MainActor in
        self?.handleAIRewording(promptKey: .aiRewordingPrompt3, promptNumber: 3)
      }
    }
    
    print("DEBUG: AI Rewording hotkeys setup complete")
  }
  
  @MainActor
  private func handleAIRewording(promptKey: Defaults.Key<String>, promptNumber: Int) {
    print("DEBUG: handleAIRewording() called for prompt \(promptNumber)")
    
    // Check clipboard history
    let historyItems = History.shared.all
    print("DEBUG: History has \(historyItems.count) items")
    
    guard let mostRecentItem = historyItems.first else {
      print("DEBUG: No clipboard items found for AI Rewording \(promptNumber)")
      return
    }
    
    print("DEBUG: Most recent clipboard item: '\(mostRecentItem.text.prefix(50))'...")
    
    // Check prompt configuration
    let prompt = Defaults[promptKey]
    print("DEBUG: AI Rewording prompt \(promptNumber) from defaults: '\(prompt)'")
    guard !prompt.isEmpty else {
      print("DEBUG: AI Rewording prompt \(promptNumber) is empty")
      return
    }
    
    // Check API key configuration
    let apiKey = Defaults[.azureOpenAIApiKey]
    print("DEBUG: API Key configured: \(apiKey.isEmpty ? "No" : "Yes (\(apiKey.count) characters)")")
    guard !apiKey.isEmpty else {
      print("DEBUG: OpenAI API key is empty or not configured")
      return
    }
    
    let textToReword = mostRecentItem.text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    print("DEBUG: Starting AI rewording request for prompt \(promptNumber)")
    print("DEBUG: Text to reword: '\(textToReword)'")
    print("DEBUG: Prompt: '\(prompt)'")
    print("DEBUG: API Key exists: \(apiKey.count > 0 ? "Yes (\(String(apiKey.prefix(8)))...)" : "No")")
    
    // Send request to OpenAI
    Task {
      do {
        print("DEBUG: Sending OpenAI request for rewording...")
        let rewordedText = try await sendOpenAIRequest(prompt: prompt, text: textToReword, apiKey: apiKey)
        print("DEBUG: OpenAI response received (length: \(rewordedText.count) characters)")
        print("DEBUG: Reworded text preview: '\(rewordedText.prefix(100))'...")
        
        // Copy the reworded text to clipboard
        await MainActor.run {
          print("DEBUG: Copying reworded text to clipboard...")
          Clipboard.shared.copy(rewordedText)
          print("DEBUG: Successfully copied reworded text to clipboard")
        }
      } catch {
        print("DEBUG: OpenAI API error in AI Rewording \(promptNumber): \(error)")
      }
    }
  }
}

enum OpenAIError: Error {
  case invalidResponse
  case invalidResponseFormat
}
