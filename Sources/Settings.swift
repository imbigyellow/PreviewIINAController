import AppKit

// Physical ANSI letter/number positions; no layout or Accessibility queries in the tap.
let keyLabels: [Int64: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",25:"9",26:"7",28:"8",29:"0",31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M"]

struct Settings: Codable, Equatable {
    var backKey: Int64 = 12
    var pauseKey: Int64 = 13
    var forwardKey: Int64 = 14
    var backSeconds: Int = 5
    var forwardSeconds: Int = 5
    static let storageKey = "controls.v1"
    var isValid: Bool {
        let keys = [backKey, pauseKey, forwardKey]
        return keys.allSatisfy { keyLabels[$0] != nil } && Set(keys).count == 3
            && (1...3600).contains(backSeconds) && (1...3600).contains(forwardSeconds)
    }
    static func load(from defaults: UserDefaults = .standard) -> Settings {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Settings.self, from: data), value.isValid
        else { return Settings() }
        return value
    }
    func save(to defaults: UserDefaults = .standard) -> Bool {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return true
    }
}

// Only records real keyDown events while this button has focus in our settings window.
final class KeyButton: NSButton {
    var code: Int64 { didSet {
        title = keyLabels[code] ?? "?"
        setAccessibilityLabel("快捷键 " + title)
    } }
    private var recording = false
    init(_ code: Int64) {
        self.code = code
        super.init(frame: .zero)
        title = keyLabels[code] ?? "?"
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
        setAccessibilityLabel("快捷键 " + title)
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override var acceptsFirstResponder: Bool { true }
    @objc private func beginRecording() {
        window?.makeFirstResponder(self)
        recording = true
        title = "请按字母或数字…"
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { finish(); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isEmpty, keyLabels[Int64(event.keyCode)] != nil else { NSSound.beep(); return }
        code = Int64(event.keyCode)
        finish()
    }
    private func finish() {
        recording = false
        title = keyLabels[code] ?? "?"
        setAccessibilityLabel("快捷键 " + title)
    }
    override func resignFirstResponder() -> Bool { finish(); return super.resignFirstResponder() }
}

final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let back: KeyButton
    private let pause: KeyButton
    private let forward: KeyButton
    private let backSeconds: NSTextField
    private let forwardSeconds: NSTextField
    private let status = NSTextField(labelWithString: "")
    private let apply: (Settings) -> Void
    var onClose: (() -> Void)?

    init(settings: Settings, apply: @escaping (Settings) -> Void) {
        self.apply = apply
        back = KeyButton(settings.backKey)
        pause = KeyButton(settings.pauseKey)
        forward = KeyButton(settings.forwardKey)
        backSeconds = NSTextField(string: String(settings.backSeconds))
        forwardSeconds = NSTextField(string: String(settings.forwardSeconds))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 310),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "PreviewIINAController 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)
        ])
        root.addArrangedSubview(NSTextField(labelWithString: "仅在预览位于前台时生效 · 修饰键组合始终放行"))
        backSeconds.setAccessibilityLabel("后退秒数")
        forwardSeconds.setAccessibilityLabel("前进秒数")
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "按键"), NSTextField(labelWithString: "操作"), NSTextField(labelWithString: "秒数")],
            [back, NSTextField(labelWithString: "后退"), backSeconds],
            [pause, NSTextField(labelWithString: "播放 / 暂停"), NSTextField(labelWithString: "—")],
            [forward, NSTextField(labelWithString: "前进"), forwardSeconds]
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 20
        grid.column(at: 0).width = 165
        grid.column(at: 1).width = 140
        grid.column(at: 2).width = 80
        root.addArrangedSubview(grid)
        let hint = NSTextField(labelWithString: "点击按键后录入字母或数字；秒数为 1–3600 的整数。")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        root.addArrangedSubview(hint)
        status.textColor = .systemRed
        status.font = .systemFont(ofSize: 11)
        root.addArrangedSubview(status)
        let reset = NSButton(title: "恢复默认", target: self, action: #selector(resetValues))
        let save = NSButton(title: "保存", target: self, action: #selector(saveValues))
        let buttons = NSStackView(views: [reset, save])
        buttons.spacing = 16
        root.addArrangedSubview(buttons)
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    @objc private func resetValues() {
        window?.makeFirstResponder(nil)
        back.code = 12; pause.code = 13; forward.code = 14
        backSeconds.stringValue = "5"; forwardSeconds.stringValue = "5"
        status.stringValue = "已恢复默认，点击保存后生效。"
    }
    @objc private func saveValues() {
        window?.makeFirstResponder(nil)
        guard let b = Int(backSeconds.stringValue.trimmingCharacters(in: .whitespaces)),
              let f = Int(forwardSeconds.stringValue.trimmingCharacters(in: .whitespaces)) else {
            status.stringValue = "请输入 1–3600 的整数秒数。"; return
        }
        let value = Settings(backKey: back.code, pauseKey: pause.code, forwardKey: forward.code,
                             backSeconds: b, forwardSeconds: f)
        guard value.isValid else {
            status.stringValue = "三个按键不能重复；秒数须为 1–3600 的整数。"; return
        }
        apply(value)
        close()
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
