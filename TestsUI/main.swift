import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
var saved: Settings?
let panel = SettingsWindow(settings: Settings()) { saved = $0 }
panel.showWindow(nil)
panel.window!.appearance = NSAppearance(named: .aqua)
RunLoop.main.run(until: Date().addingTimeInterval(0.3))
let content = panel.window!.contentView!
content.layoutSubtreeIfNeeded()
func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
let views = descendants(content)
let buttons = views.compactMap { $0 as? NSButton }
let keys = views.compactMap { $0 as? KeyButton }
let fields = views.compactMap { $0 as? NSTextField }.filter { $0.isEditable }
let save = buttons.first { $0.title == "保存" }!
let reset = buttons.first { $0.title == "恢复默认" }!
precondition(keys.count == 3 && fields.count == 2)
for view in views where view is NSControl {
    let rect = view.convert(view.bounds, to: content)
    precondition(content.bounds.contains(rect), "Clipped control: \(view)")
}
keys[1].code = keys[0].code
save.performClick(nil)
precondition(saved == nil && panel.window!.isVisible)
reset.performClick(nil)
fields[0].stringValue = "0"
save.performClick(nil)
precondition(saved == nil)
fields[0].stringValue = "3"
fields[1].stringValue = "7"
keys[0].code = 0
save.performClick(nil)
precondition(saved == Settings(backKey: 0, pauseKey: 13, forwardKey: 14, backSeconds: 3, forwardSeconds: 7))
precondition(!panel.window!.isVisible)
print("PASS: native settings layout, duplicate rejection, range rejection, reset, save and close; no keyboard injection")
