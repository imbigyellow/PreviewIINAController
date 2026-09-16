import AppKit
import CoreGraphics
import Darwin

enum Command: Sendable {
    case back, pause, forward
    var payload: [UInt8] {
        let json: String
        switch self {
        case .back: json = "{\"command\":[\"seek\",-5,\"relative\"]}\n"
        case .pause: json = "{\"command\":[\"cycle\",\"pause\"]}\n"
        case .forward: json = "{\"command\":[\"seek\",5,\"relative\"]}\n"
        }
        return Array(json.utf8)
    }
}

// Pure filtering: no event creation, mutation or injection.
func commandForKey(_ key: Int64, flags: CGEventFlags) -> Command? {
    guard key == 12 || key == 13 || key == 14 else { return nil }
    // NonCoalesced is event metadata, not a modifier. Unknown flags fail open.
    guard flags.rawValue & ~CGEventFlags.maskNonCoalesced.rawValue == 0 else { return nil }
    switch key {
    case 12: return .back
    case 13: return .pause
    default: return .forward
    }
}

final class IPC: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.PreviewIINAController.iinaIPCQueue")
    func submit(_ command: Command) {
        queue.async { Self.send(command.payload) }
    }
    private static func send(_ bytes: [UInt8]) {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }
        var yes: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes,
                         socklen_t(MemoryLayout.size(ofValue: yes))) == 0,
              fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { return }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array("/tmp/iina-socket".utf8CString)
        withUnsafeMutableBytes(of: &address.sun_path) { target in
            path.withUnsafeBytes { source in target.copyBytes(from: source) }
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        // AF_UNIX normally connects immediately. Busy peers fail silently as well.
        guard connected == 0 else { return }
        bytes.withUnsafeBytes { buffer in
            var offset = 0
            var interruptions = 0
            while offset < buffer.count {
                let count = Darwin.send(fd, buffer.baseAddress!.advanced(by: offset),
                                        buffer.count - offset, 0)
                if count > 0 { offset += count }
                else if count < 0 && errno == EINTR && interruptions < 8 {
                    interruptions += 1
                } else { return } // Includes EAGAIN: never wait for a stalled player.
            }
        }
    }
}

final class Controller {
    // All mutable properties are confined to the main thread. The event source is
    // installed ONLY on the main run loop; the workspace observer uses .main.
    private var isPreviewFrontmost = false
    private var observer: NSObjectProtocol?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let ipc = IPC()

    func start() -> Bool {
        precondition(Thread.isMainThread)
        let workspace = NSWorkspace.shared
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            self?.isPreviewFrontmost = (notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier == "com.apple.Preview"
        }
        isPreviewFrontmost = workspace.frontmostApplication?.bundleIdentifier == "com.apple.Preview"
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << CGEventType.keyDown.rawValue,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<Controller>.fromOpaque(context).takeUnretainedValue()
                    .handle(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { stop(); return false }
        tap = port
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        else { stop(); return false }
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        guard let command = commandForKey(key, flags: event.flags), isPreviewFrontmost
        else { return Unmanaged.passUnretained(event) }
        ipc.submit(command)
        return nil
    }

    func stop() {
        precondition(Thread.isMainThread)
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }
}
