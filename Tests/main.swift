import Foundation

import CoreGraphics
let keys: [Int64] = [12, 13, 14]
for key in keys {
    precondition(commandForKey(key, flags: []) != nil)
    precondition(commandForKey(key, flags: .maskNonCoalesced) != nil)
    // Every modifier combination, including Fn/Caps Lock/help/numeric-pad.
    let masks: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl,
        .maskShift, .maskAlphaShift, .maskSecondaryFn, .maskHelp, .maskNumericPad]
    for combination in 1..<256 {
        var flags: CGEventFlags = []
        for bit in 0..<8 where combination & (1 << bit) != 0 { flags.formUnion(masks[bit]) }
        precondition(commandForKey(key, flags: flags) == nil)
        flags.formUnion(.maskNonCoalesced)
        precondition(commandForKey(key, flags: flags) == nil)
    }
}
for key: Int64 in 0..<128 where !keys.contains(key) {
    precondition(commandForKey(key, flags: []) == nil)
}
precondition(String(decoding: Command.back.payload(), as: UTF8.self) == "{\"command\":[\"seek\",-5,\"relative\"]}\n")
precondition(String(decoding: Command.pause.payload(), as: UTF8.self) == "{\"command\":[\"cycle\",\"pause\"]}\n")
precondition(String(decoding: Command.forward.payload(), as: UTF8.self) == "{\"command\":[\"seek\",5,\"relative\"]}\n")
print("PASS: key filtering, all 255 modifier combinations, command payloads; no injected events")

var custom = Settings(backKey: 0, pauseKey: 1, forwardKey: 2, backSeconds: 3, forwardSeconds: 7)
precondition(custom.isValid)
precondition(commandForKey(12, flags: [], settings: custom) == nil)
precondition(commandForKey(0, flags: [], settings: custom) == .back)
precondition(commandForKey(1, flags: [], settings: custom) == .pause)
precondition(commandForKey(2, flags: [], settings: custom) == .forward)
for key: Int64 in [0,1,2] {
    for flags: CGEventFlags in [.maskCommand, .maskShift, .maskControl, .maskAlternate, .maskAlphaShift, .maskSecondaryFn] {
        precondition(commandForKey(key, flags: flags, settings: custom) == nil)
    }
}
precondition(String(decoding: Command.back.payload(backSeconds: 3), as: UTF8.self) == "{\"command\":[\"seek\",-3,\"relative\"]}\n")
precondition(String(decoding: Command.forward.payload(forwardSeconds: 7), as: UTF8.self) == "{\"command\":[\"seek\",7,\"relative\"]}\n")
let suite = "PreviewIINAController.tests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
precondition(Settings.load(from: defaults) == Settings())
precondition(custom.save(to: defaults))
precondition(Settings.load(from: defaults) == custom)
custom.pauseKey = custom.backKey
precondition(!custom.isValid && !custom.save(to: defaults))
custom = Settings(); custom.backSeconds = 0
precondition(!custom.isValid)
custom = Settings(); custom.forwardSeconds = 3601
precondition(!custom.isValid)
custom = Settings(); custom.backKey = 53
precondition(!custom.isValid)
defaults.set(Data("invalid".utf8), forKey: Settings.storageKey)
precondition(Settings.load(from: defaults) == Settings())
defaults.set(try! JSONEncoder().encode(custom), forKey: Settings.storageKey)
precondition(Settings.load(from: defaults) == Settings())
print("PASS: custom mappings, modifiers, seek values, duplicate/range validation, persistence and corrupt-settings fallback")

let customMapping = Settings(backKey: 0, pauseKey: 1, forwardKey: 2, backSeconds: 3, forwardSeconds: 7)
let allMasks: [CGEventFlags] = [.maskCommand,.maskAlternate,.maskControl,.maskShift,.maskAlphaShift,.maskSecondaryFn,.maskHelp,.maskNumericPad]
for key: Int64 in [0,1,2] {
    for combination in 1..<256 {
        var flags: CGEventFlags = []
        for bit in 0..<8 where combination & (1 << bit) != 0 { flags.formUnion(allMasks[bit]) }
        precondition(commandForKey(key, flags: flags, settings: customMapping) == nil)
    }
}
print("PASS: all modifier combinations with custom mappings")
