import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let popup = Self("popup", default: Shortcut(.c, modifiers: [.command, .shift]))
  static let pin = Self("pin", default: Shortcut(.p, modifiers: [.option]))
  static let delete = Self("delete", default: Shortcut(.delete, modifiers: [.option]))
  static let aiRewording1 = Self("aiRewording1", default: Shortcut(.one, modifiers: [.command, .option]))
  static let aiRewording2 = Self("aiRewording2", default: Shortcut(.two, modifiers: [.command, .option]))
  static let aiRewording3 = Self("aiRewording3", default: Shortcut(.three, modifiers: [.command, .option]))
  static let aiDefine = Self("aiDefine", default: Shortcut(.d, modifiers: [.command, .option]))
}
