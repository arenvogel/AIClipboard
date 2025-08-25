import SwiftUI
import KeyboardShortcuts
import Defaults
import Settings

struct AIRewordingSettingsView: View {
  @Default(.aiRewordingPrompt1) private var prompt1: String
  @Default(.aiRewordingPrompt2) private var prompt2: String
  @Default(.aiRewordingPrompt3) private var prompt3: String

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(title: "Prompt 1") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Hotkey:")
            KeyboardShortcuts.Recorder(for: .aiRewording1)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Prompt:")
            TextField("Enter AI prompt", text: $prompt1, axis: .vertical)
              .textFieldStyle(.roundedBorder)
              .lineLimit(3...6)
          }
        }
      }
      
      Settings.Section(title: "Prompt 2") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Hotkey:")
            KeyboardShortcuts.Recorder(for: .aiRewording2)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Prompt:")
            TextField("Enter AI prompt", text: $prompt2, axis: .vertical)
              .textFieldStyle(.roundedBorder)
              .lineLimit(3...6)
          }
        }
      }
      
      Settings.Section(title: "Prompt 3") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Hotkey:")
            KeyboardShortcuts.Recorder(for: .aiRewording3)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Prompt:")
            TextField("Enter AI prompt", text: $prompt3, axis: .vertical)
              .textFieldStyle(.roundedBorder)
              .lineLimit(3...6)
          }
        }
      }
    }
  }
}

#Preview {
  AIRewordingSettingsView()
}
