import Foundation

/// The three legacy command collections, each edited on its own settings page.
enum DeviceKind: String, CaseIterable, Identifiable {
    case trackpad
    case magicMouse
    case drawing

    var id: String { rawValue }

    var commandsKey: String {
        switch self {
        case .trackpad: return JTTrackpadCommandsKey
        case .magicMouse: return JTMagicMouseCommandsKey
        case .drawing: return JTRecognitionCommandsKey
        }
    }

    var title: String {
        switch self {
        case .trackpad: return "Trackpad"
        case .magicMouse: return "Magic Mouse"
        case .drawing: return "Drawing"
        }
    }

    var gestureCatalog: [String] {
        switch self {
        case .trackpad:
            return [
                "One-Fix Left-Tap", "One-Fix Right-Tap", "One-Fix One-Slide",
                "One-Fix Two-Slide-Up", "One-Fix Two-Slide-Down",
                "One-Fix-Press Two-Slide-Up", "One-Fix-Press Two-Slide-Down",
                "Two-Fix Index-Double-Tap", "Two-Fix Middle-Double-Tap",
                "Two-Fix Ring-Double-Tap", "Two-Fix One-Slide-Up",
                "Two-Fix One-Slide-Down", "Two-Fix One-Slide-Left",
                "Two-Fix One-Slide-Right", "Three-Finger Tap", "Three-Finger Click",
                "Three-Finger Pinch-In", "Three-Finger Pinch-Out", "Three-Swipe-Up",
                "Three-Swipe-Down", "Three-Swipe-Left", "Three-Swipe-Right",
                "Four-Finger Tap", "Four-Finger Click", "Four-Swipe-Up",
                "Four-Swipe-Down", "Four-Swipe-Left", "Four-Swipe-Right",
                "Pinky-To-Index", "Index-To-Pinky", "Left-Side Scroll",
                "Right-Side Scroll", "Left-Side Volume Scrub",
                "Right-Side Volume Scrub", "All Unassigned Gestures",
            ]
        case .magicMouse:
            return [
                "Middle-Fix Index-Near-Tap", "Middle-Fix Index-Far-Tap",
                "Index-Fix Middle-Near-Tap", "Index-Fix Middle-Far-Tap",
                "Middle-Fix Index-Slide-Out", "Middle-Fix Index-Slide-In",
                "Index-Fix Middle-Slide-Out", "Index-Fix Middle-Slide-In",
                "Three-Swipe-Left", "Three-Swipe-Right", "Three-Swipe-Up",
                "Three-Swipe-Down", "Three-Finger Click", "V-Shape", "Middle Click",
                "Two-Fix One-Slide-Up", "Two-Fix One-Slide-Down",
                "Two-Fix One-Slide-Left", "Two-Fix One-Slide-Right", "Thumb",
                "All Unassigned Gestures",
            ]
        case .drawing:
            return [
                "A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
                "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
                "V", "W", "X", "Y", "Z", "Up", "Down", "Left", "Right",
                "Left-Right", "Right-Left", "Up-Left", "Up-Right", "Left-Up",
                "Right-Up", "/ Up", "/ Down", "\\ Up", "\\ Down",
                "All Unassigned Gestures",
            ]
        }
    }

    var builtInActions: [String] {
        var actions = [
            "-", "Copy", "Paste", "New", "Open", "Save", "New Tab",
            "Close / Close Tab", "Quit", "Hide", "Minimize", "Zoom",
            "Maximize", "Un-Maximize", "Maximize Left", "Maximize Right",
            "Refresh", "Next Tab", "Previous Tab", "Open Recently Closed Tab",
            "Full Screen", "Launch Finder", "Launch Browser", "Show Desktop",
            "Mission Control", "Application Windows", "Application Switcher",
            "Previous Window",
            "Launchpad", "Scroll to Top", "Scroll to Bottom", "Play / Pause",
            "Next", "Previous", "Volume Up", "Volume Down", "Brightness Up",
            "Brightness Down",
        ]
        if self != .drawing {
            actions += ["Left Click", "Right Click", "Middle Click",
                        "Open Link in New Tab", "Select Tab Above Cursor"]
        }
        return actions
    }
}

let allApplicationsName = "All Applications"

/// Editor rules shared by the assignment list and the edit sheet. They mirror
/// what the engine enforces so the UI never saves a row the engine ignores.
enum AssignmentRules {
    /// Gestures whose engine behavior is fixed; their action cannot be changed.
    static func requiredAction(for gesture: String, kind: DeviceKind) -> String? {
        if gesture.isEmpty { return nil }
        if gesture == "All Unassigned Gestures" { return "-" }
        switch kind {
        case .trackpad:
            switch gesture {
            case "One-Fix One-Slide": return "Move / Resize"
            case "Left-Side Scroll", "Right-Side Scroll": return "Auto Scroll"
            case "Left-Side Volume Scrub", "Right-Side Volume Scrub": return "Volume Scrub"
            default: return nil
            }
        case .magicMouse:
            switch gesture {
            case "V-Shape": return "Move / Resize"
            case "Thumb": return "Quick Tab Switching"
            default: return nil
            }
        case .drawing:
            return nil
        }
    }

    /// Volume scrub is a system-level control read only from All Applications.
    static func requiresAllApplications(_ gesture: String, kind: DeviceKind) -> Bool {
        kind == .trackpad &&
            (gesture == "Left-Side Volume Scrub" || gesture == "Right-Side Volume Scrub")
    }

    static func isBlockedByDragProtection(_ gesture: String, kind: DeviceKind,
                                          protectionOn: Bool) -> Bool {
        kind == .trackpad && protectionOn && JTThreeFingerGestureConflictsWithNativeDrag(gesture)
    }

    static func dragConflictMessage(for gesture: String) -> String {
        "\(gesture) moves or clicks with the same three fingers macOS uses for dragging. " +
            "Turn off Three-Finger Drag Protection to enable it."
    }

    static func allApplicationsMessage(for gesture: String) -> String {
        "\(gesture) is a system-wide trackpad control, so it can only be assigned to All Applications."
    }

    static func actionTitle(_ action: String) -> String {
        action == "-" ? "Do Nothing" : action
    }

    static func describe(command: [String: Any]) -> String {
        let isAction = (command["IsAction"] as? NSNumber)?.boolValue ?? false
        if !isAction {
            if let name = command["Command"] as? String, !name.isEmpty { return name }
            let flags = (command["ModifierFlags"] as? NSNumber)?.uint64Value ?? 0
            var text = ""
            if flags & CGEventFlags.maskControl.rawValue != 0 { text += "⌃" }
            if flags & CGEventFlags.maskAlternate.rawValue != 0 { text += "⌥" }
            if flags & CGEventFlags.maskShift.rawValue != 0 { text += "⇧" }
            if flags & CGEventFlags.maskCommand.rawValue != 0 { text += "⌘" }
            return text + "Key \((command["KeyCode"] as? NSNumber)?.intValue ?? 0)"
        }
        if let path = command["OpenFilePath"] as? String {
            return "Open \((path as NSString).lastPathComponent)"
        }
        if let url = command["OpenURL"] as? String {
            return "Open \(URL(string: url)?.host ?? url)"
        }
        return actionTitle(command["Command"] as? String ?? "(unknown)")
    }

    static func symbol(for gesture: String, kind: DeviceKind) -> String {
        let name = gesture.lowercased()
        if name == "all unassigned gestures" { return "asterisk" }
        if name.contains("volume") { return "speaker.wave.2" }
        if name.contains("scroll") { return "scroll" }
        if name.contains("pinch-in") { return "arrow.down.right.and.arrow.up.left" }
        if name.contains("pinch-out") { return "arrow.up.left.and.arrow.down.right" }
        if name == "pinky-to-index" { return "arrow.left.to.line" }
        if name == "index-to-pinky" { return "arrow.right.to.line" }
        if name == "thumb" { return "hand.thumbsup" }
        if name == "v-shape" { return "arrow.up.and.down.and.arrow.left.and.right" }
        if name == "middle click" { return "computermouse" }
        if name.contains("one-fix one-slide") { return "arrow.up.and.down.and.arrow.left.and.right" }
        if name.hasSuffix("up") { return "arrow.up" }
        if name.hasSuffix("down") { return "arrow.down" }
        if name.hasSuffix("left") { return "arrow.left" }
        if name.hasSuffix("right") { return "arrow.right" }
        if name.hasSuffix("slide-out") { return "arrow.up.right" }
        if name.hasSuffix("slide-in") { return "arrow.down.left" }
        if name.contains("click") { return "cursorarrow.click" }
        if name.contains("tap") { return "hand.tap" }
        return "hand.point.up.left"
    }
}
