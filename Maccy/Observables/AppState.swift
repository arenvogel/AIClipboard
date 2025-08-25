import AppKit
import Defaults
import Foundation
import Settings
import SwiftUI
import KeyboardShortcuts

@Observable
class AppState: Sendable {
  static let shared = AppState()

  var appDelegate: AppDelegate?
  var popup: Popup
  var history: History
  var footer: Footer

  var scrollTarget: UUID?
  var selection: UUID? {
    didSet {
      selectWithoutScrolling(selection)
      scrollTarget = selection
    }
  }

  func selectWithoutScrolling(_ item: UUID?) {
    history.selectedItem = nil
    footer.selectedItem = nil

    if let item = history.items.first(where: { $0.id == item }) {
      history.selectedItem = item
    } else if let item = footer.items.first(where: { $0.id == item }) {
      footer.selectedItem = item
    }
  }

  var hoverSelectionWhileKeyboardNavigating: UUID?
  var isKeyboardNavigating: Bool = true {
    didSet {
      if let hoverSelection = hoverSelectionWhileKeyboardNavigating {
        hoverSelectionWhileKeyboardNavigating = nil
        selection = hoverSelection
      }
    }
  }

  var searchVisible: Bool {
    if !Defaults[.showSearch] { return false }
    switch Defaults[.searchVisibility] {
    case .always: return true
    case .duringSearch: return !history.searchQuery.isEmpty
    }
  }

  var menuIconText: String {
    var title = history.unpinnedItems.first?.text.shortened(to: 100)
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    title.unicodeScalars.removeAll(where: CharacterSet.newlines.contains)
    return title.shortened(to: 20)
  }

  private let about = About()
  private var settingsWindowController: SettingsWindowController?

  init() {
    history = History.shared
    footer = Footer()
    popup = Popup()
  }

  @MainActor
  func select() {
    if let item = history.selectedItem, history.items.contains(item) {
      history.select(item)
    } else if let item = footer.selectedItem {
      // TODO: Use item.suppressConfirmation, but it's not updated!
      if item.confirmation != nil, Defaults[.suppressClearAlert] == false {
        item.showConfirmation = true
      } else {
        item.action()
      }
    } else {
      Clipboard.shared.copy(history.searchQuery)
      history.searchQuery = ""
    }
  }

  private func selectFromKeyboardNavigation(_ id: UUID?) {
    isKeyboardNavigating = true
    selection = id
  }

  func highlightFirst() {
    if let item = history.items.first(where: \.isVisible) {
      selectFromKeyboardNavigation(item.id)
    }
  }

  func highlightPrevious() {
    isKeyboardNavigating = true
    if let selectedItem = history.selectedItem {
      if let nextItem = history.items.filter(\.isVisible).item(before: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    } else if let selectedItem = footer.selectedItem {
      if let nextItem = footer.items.filter(\.isVisible).item(before: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      } else if selectedItem == footer.items.first(where: \.isVisible),
                let nextItem = history.items.last(where: \.isVisible) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    }
  }

  func highlightNext(allowCycle: Bool = false) {
    if let selectedItem = history.selectedItem {
      if let nextItem = history.items.filter(\.isVisible).item(after: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      } else if selectedItem == history.items.filter(\.isVisible).last,
                let nextItem = footer.items.first(where: \.isVisible) {
        selectFromKeyboardNavigation(nextItem.id)
      }
    } else if let selectedItem = footer.selectedItem {
      if let nextItem = footer.items.filter(\.isVisible).item(after: selectedItem) {
        selectFromKeyboardNavigation(nextItem.id)
      } else if allowCycle {
        // End of footer; cycle to the beginning
        highlightFirst()
      }
    } else {
      selectFromKeyboardNavigation(footer.items.first(where: \.isVisible)?.id)
    }
  }

  func highlightLast() {
    if let selectedItem = history.selectedItem {
      if selectedItem == history.items.filter(\.isVisible).last,
         let nextItem = footer.items.first(where: \.isVisible) {
        selectFromKeyboardNavigation(nextItem.id)
      } else {
        selectFromKeyboardNavigation(history.items.last(where: \.isVisible)?.id)
      }
    } else if footer.selectedItem != nil {
      selectFromKeyboardNavigation(footer.items.last(where: \.isVisible)?.id)
    } else {
      selectFromKeyboardNavigation(footer.items.first(where: \.isVisible)?.id)
    }
  }

  func openAbout() {
    about.openAbout(nil)
  }

  @MainActor
  func openPreferences() { // swiftlint:disable:this function_body_length
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(
        panes: [
          Settings.Pane(
            identifier: Settings.PaneIdentifier.general,
            title: NSLocalizedString("Title", tableName: "GeneralSettings", comment: ""),
            toolbarIcon: NSImage.gearshape!
          ) {
            GeneralSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.storage,
            title: NSLocalizedString("Title", tableName: "StorageSettings", comment: ""),
            toolbarIcon: NSImage.externaldrive!
          ) {
            StorageSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.appearance,
            title: NSLocalizedString("Title", tableName: "AppearanceSettings", comment: ""),
            toolbarIcon: NSImage.paintpalette!
          ) {
            AppearanceSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.pins,
            title: NSLocalizedString("Title", tableName: "PinsSettings", comment: ""),
            toolbarIcon: NSImage.pincircle!
          ) {
            PinsSettingsPane()
              .environment(self)
              .modelContainer(Storage.shared.container)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.ignore,
            title: NSLocalizedString("Title", tableName: "IgnoreSettings", comment: ""),
            toolbarIcon: NSImage.nosign!
          ) {
            IgnoreSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.advanced,
            title: NSLocalizedString("Title", tableName: "AdvancedSettings", comment: ""),
            toolbarIcon: NSImage.gearshape2!
          ) {
            AdvancedSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.aiRewording,
            title: "AI Rewording",
            toolbarIcon: NSImage(systemSymbolName: "sparkles", accessibilityDescription: "sparkles")!
            
          ) {
            Settings.Container(contentWidth: 450) {
              // OpenAI API Key Section
              Settings.Section(title: "OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                  Text("OpenAI API Key")
                    .font(.headline)
                  
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Enter your OpenAI API key:")
                      .foregroundColor(.secondary)
                    SecureField("API Key", text: Binding(
                      get: { Defaults[.azureOpenAIApiKey] },
                      set: { Defaults[.azureOpenAIApiKey] = $0 }
                    ))
                      .textFieldStyle(.roundedBorder)
                    
                    Text("Your API key will be stored securely and used for AI rewording requests.")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
              }
              
              Settings.Section(title: "AI Rewording Configuration") {
                VStack(spacing: 20) {
                  Text("Configure hotkeys and prompts for AI rewording")
                    .foregroundColor(.secondary)
                  
                  // Prompt 1
                  VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt 1")
                      .font(.headline)
                    
                    HStack {
                      Text("Hotkey:")
                      KeyboardShortcuts.Recorder(for: .aiRewording1)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                      Text("Prompt:")
                      TextField("Enter AI prompt", text: Binding(
                        get: { Defaults[.aiRewordingPrompt1] },
                        set: { Defaults[.aiRewordingPrompt1] = $0 }
                      ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    }
                  }
                  .padding()
                  .background(Color(NSColor.controlBackgroundColor))
                  .cornerRadius(8)
                  
                  // Prompt 2
                  VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt 2")
                      .font(.headline)
                    
                    HStack {
                      Text("Hotkey:")
                      KeyboardShortcuts.Recorder(for: .aiRewording2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                      Text("Prompt:")
                      TextField("Enter AI prompt", text: Binding(
                        get: { Defaults[.aiRewordingPrompt2] },
                        set: { Defaults[.aiRewordingPrompt2] = $0 }
                      ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    }
                  }
                  .padding()
                  .background(Color(NSColor.controlBackgroundColor))
                  .cornerRadius(8)
                  
                  // Prompt 3
                  VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt 3")
                      .font(.headline)
                    
                    HStack {
                      Text("Hotkey:")
                      KeyboardShortcuts.Recorder(for: .aiRewording3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                      Text("Prompt:")
                      TextField("Enter AI prompt", text: Binding(
                        get: { Defaults[.aiRewordingPrompt3] },
                        set: { Defaults[.aiRewordingPrompt3] = $0 }
                      ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    }
                  }
                  .padding()
                  .background(Color(NSColor.controlBackgroundColor))
                  .cornerRadius(8)
                }
              }
              
              // AI Define Configuration Section
              Settings.Section(title: "AI Define Configuration") {
                VStack(spacing: 20) {
                  Text("Configure hotkey and prompt for AI definitions")
                    .foregroundColor(.secondary)
                  
                  VStack(alignment: .leading, spacing: 8) {
                    Text("AI Define")
                      .font(.headline)
                    
                    HStack {
                      Text("Hotkey:")
                      KeyboardShortcuts.Recorder(for: .aiDefine)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                      Text("Prompt:")
                      TextField("Enter AI define prompt", text: Binding(
                        get: { Defaults[.aiDefinePrompt] },
                        set: { Defaults[.aiDefinePrompt] = $0 }
                      ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                      
                      Text("This prompt will be used to generate definitions. The selected text will be appended to your prompt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                  }
                  .padding()
                  .background(Color(NSColor.controlBackgroundColor))
                  .cornerRadius(8)
                }
              }
            }
          }
        ]
      )
    }
    settingsWindowController?.show()
    settingsWindowController?.window?.orderFrontRegardless()
  }

  func quit() {
    NSApp.terminate(self)
  }
}
