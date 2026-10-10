import AppKit

@MainActor
func installMainMenu(details: Selector, guide: Selector, target: AnyObject) {
    let menu = NSMenu()
    menu.addItem(submenu("Door into Summer", [
        item("About Door into Summer", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
        .separator(),
        item("Hide Door into Summer", #selector(NSApplication.hide(_:)), "h"),
        item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
        item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
        .separator(),
        item("Quit Door into Summer", #selector(NSApplication.terminate(_:)), "q"),
    ]))
    menu.addItem(submenu("File", [item("Close", #selector(NSWindow.performClose(_:)), "w")]))
    menu.addItem(submenu("Edit", [
        item("Undo", Selector(("undo:")), "z"),
        item("Redo", Selector(("redo:")), "z", [.command, .shift]),
        .separator(),
        item("Cut", #selector(NSText.cut(_:)), "x"),
        item("Copy", #selector(NSText.copy(_:)), "c"),
        item("Paste", #selector(NSText.paste(_:)), "v"),
        item("Select All", #selector(NSText.selectAll(_:)), "a"),
    ]))
    menu.addItem(submenu("View", [item("Details", details, "b", target: target)]))
    let windows = submenu("Window", [
        item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
        item("Zoom", #selector(NSWindow.performZoom(_:))),
        .separator(),
        item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
    ])
    let help = submenu("Help", [item("Door into Summer Help", guide, target: target)])
    menu.addItem(windows)
    menu.addItem(help)
    NSApp.mainMenu = menu
    NSApp.windowsMenu = windows.submenu
    NSApp.helpMenu = help.submenu
}

private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: title)
    for entry in items {
        menu.addItem(entry)
    }
    item.submenu = menu
    return item
}

private func item(_ title: String, _ action: Selector, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    item.target = target
    return item
}
