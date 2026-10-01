import Foundation

var assertions = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    assertions += 1
    if !condition() {
        FileHandle.standardError.write("FAIL: \(message)\n".data(using: .utf8)!)
        exit(1)
    }
}

func command(_ gesture: String, _ action: String, enabled: Bool = true) -> [String: Any] {
    ["Gesture": gesture, "Command": action, "IsAction": true, "ModifierFlags": 0, "KeyCode": 0,
     "Enable": enabled]
}

let domain = "com.jitouch.Jitouch.SettingsModelTests.\(UUID().uuidString)"
let backups = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("JitouchSettingsModelTests-\(UUID().uuidString)", isDirectory: true)
let seed: [String: Any] = [
    "enAll": 1,
    JTTrackpadCommandsKey: [
        ["Application": "Safari", "Path": "/Applications/Safari.app",
         "Gestures": [command("One-Fix Left-Tap", "Previous Tab")]],
        ["Application": allApplicationsName, "Path": "",
         "Gestures": [command("Three-Swipe-Up", "Mission Control", enabled: false),
                      command("Left-Side Volume Scrub", "Volume Scrub")]],
    ],
    JTMagicMouseCommandsKey: [] as [Any],
    JTRecognitionCommandsKey: [] as [Any],
]
for (key, value) in seed {
    CFPreferencesSetAppValue(key as CFString, value as CFPropertyList, domain as CFString)
}
CFPreferencesAppSynchronize(domain as CFString)

MainActor.assumeIsolated {
    let store = JTSettingsStore(preferencesAppID: domain, backupDirectoryURL: backups)
    let model = SettingsModel(store: store, engine: JTEngineController())

    let groups = model.groups(for: .trackpad)
    check(groups.map(\.application) == [allApplicationsName, "Safari"],
          "All Applications is listed first, then apps alphabetically")
    check(groups[0].assignments.count == 2 && groups[1].assignments.count == 1,
          "assignments stay under their application")
    check(Set(groups.flatMap(\.assignments).map(\.id)).count == 3, "assignment ids are unique")
    if case .active = model.status {} else { check(false, "enabled store with a running engine is active") }

    let swipe = groups[0].assignments[0]
    check(!swipe.isEnabled, "disabled flag is read from the command")
    model.setEnabled(true, for: swipe, kind: .trackpad)
    check(model.groups(for: .trackpad)[0].assignments[0].isEnabled == false,
          "drag protection blocks enabling a three-finger swipe")
    check(model.errorMessage != nil, "a blocked toggle explains why")
    model.errorMessage = nil

    store.setBool(false, forKey: JTNativeThreeFingerDragProtectionKey)
    model.setEnabled(true, for: model.groups(for: .trackpad)[0].assignments[0], kind: .trackpad)
    check(model.groups(for: .trackpad)[0].assignments[0].isEnabled,
          "toggling writes through the store once protection is off")

    let tap = model.groups(for: .trackpad)[1].assignments[0]
    model.delete(tap, kind: .trackpad)
    check(model.groups(for: .trackpad).map(\.application) == [allApplicationsName],
          "deleting the only gesture of an app removes its group")

    store.isEnabled = false
    if case .paused = model.status {} else { check(false, "disabling gestures reports paused") }

    check(AssignmentRules.requiredAction(for: "Left-Side Scroll", kind: .trackpad) == "Auto Scroll",
          "side scroll is locked to Auto Scroll")
    check(AssignmentRules.requiredAction(for: "Thumb", kind: .magicMouse) == "Quick Tab Switching",
          "thumb is locked to Quick Tab Switching")
    check(AssignmentRules.requiredAction(for: "A", kind: .drawing) == nil, "letters take any action")
    check(AssignmentRules.requiresAllApplications("Right-Side Volume Scrub", kind: .trackpad),
          "volume scrub is global only")
    check(!AssignmentRules.requiresAllApplications("Right-Side Volume Scrub", kind: .magicMouse),
          "the global-only rule is trackpad specific")
    check(AssignmentRules.describe(command: ["IsAction": false, "Command": "", "KeyCode": 4,
                                             "ModifierFlags": CGEventFlags.maskCommand.rawValue]) == "⌘Key 4",
          "unnamed shortcuts are described by modifiers and key code")
    check(AssignmentRules.describe(command: ["IsAction": true, "Command": "Open Website",
                                             "OpenURL": "https://example.com/a"]) == "Open example.com",
          "websites are described by host")
    check(AssignmentRules.actionTitle("-") == "Do Nothing", "the empty action reads as Do Nothing")
    check(DeviceKind.trackpad.builtInActions.contains("Previous Window"),
          "Previous Window is offered as a built-in action")
    check(!DeviceKind.drawing.builtInActions.contains("Left Click"),
          "pointer actions are not offered for drawing")
}

CFPreferencesSetMultiple(nil, Array(seed.keys) as CFArray, domain as CFString,
                         kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
CFPreferencesSetAppValue(JTNativeThreeFingerDragProtectionKey as CFString, nil, domain as CFString)
CFPreferencesAppSynchronize(domain as CFString)
try? FileManager.default.removeItem(at: backups)
let plist = ("~/Library/Preferences/\(domain).plist" as NSString).expandingTildeInPath
try? FileManager.default.removeItem(atPath: plist)
print("settings model tests passed (\(assertions) assertions)")
