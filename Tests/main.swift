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
precondition(String(decoding: Command.back.payload, as: UTF8.self) == "{\"command\":[\"seek\",-3,\"relative\"]}\n")
precondition(String(decoding: Command.pause.payload, as: UTF8.self) == "{\"command\":[\"cycle\",\"pause\"]}\n")
precondition(String(decoding: Command.forward.payload, as: UTF8.self) == "{\"command\":[\"seek\",5,\"relative\"]}\n")
print("PASS: key filtering, all 255 modifier combinations, command payloads; no injected events")
