import SwiftUI

struct AIDefineWindow: View {
  let definition: String
  let term: String
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack {
        VStack(alignment: .leading) {
          Text("Definition")
            .font(.title2)
            .fontWeight(.semibold)
          
          Text("Term: \(term)")
            .font(.headline)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        Button("Close") {
          dismiss()
        }
        .keyboardShortcut(.escape)
      }
      
      Divider()
      
      // Definition content
      ScrollView {
        Text(definition)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 4)
      }
      .frame(minHeight: 100, maxHeight: 400)
      
      // Footer with copy button
      HStack {
        Spacer()
        
        Button("Copy Definition") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(definition, forType: .string)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(20)
    .frame(width: 500, height: 350)
    .background(Color(NSColor.windowBackgroundColor))
  }
}

struct AIDefineWindowController {
  private var window: NSWindow?
  
  mutating func show(definition: String, term: String) {
    // Close existing window if open
    window?.close()
    
    let contentView = AIDefineWindow(definition: definition, term: term)
    
    let hostingController = NSHostingController(rootView: contentView)
    
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    
    window?.title = "AI Definition"
    window?.contentViewController = hostingController
    window?.center()
    window?.setFrameAutosaveName("AIDefineWindow")
    window?.isReleasedWhenClosed = false
    
    // Make window appear above other windows
    window?.level = .floating
    window?.makeKeyAndOrderFront(nil)
    
    // Focus the window
    NSApp.activate(ignoringOtherApps: true)
  }
  
    mutating func close() {
    window?.close()
    window = nil
  }
}
