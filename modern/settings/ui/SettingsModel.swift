import AppKit
import Combine
import ServiceManagement
import SwiftUI

struct Assignment: Identifiable {
    let id: Int
    let application: String
    let path: String
    let command: [String: Any]

    var gesture: String { command["Gesture"] as? String ?? "(unknown)" }
    var isEnabled: Bool { (command["Enable"] as? NSNumber)?.boolValue ?? false }
}

struct AssignmentGroup: Identifiable {
    var id: String { application }
    let application: String
    let path: String
    var assignments: [Assignment]
}

enum EngineStatus {
    case active
    case paused
    case needsPermission(String)
    case stopped

    var title: String {
        switch self {
        case .active: return "Gestures are active"
        case .paused: return "Gestures are paused"
        case .needsPermission: return "Permission required"
        case .stopped: return "Gesture engine is stopped"
        }
    }

    var detail: String? {
        switch self {
        case .needsPermission(let detail): return detail
        case .stopped: return "Check permissions, then retry."
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .paused: return .secondary
        case .needsPermission, .stopped: return .orange
        }
    }

    var needsAttention: Bool {
        switch self {
        case .needsPermission, .stopped: return true
        default: return false
        }
    }
}

/// Publishes the live preference domain and engine state to SwiftUI. All writes
/// go through JTSettingsStore, which backs up, validates and notifies the engine.
@MainActor
final class SettingsModel: ObservableObject {
    let store: JTSettingsStore
    let engine: JTEngineController

    @Published private(set) var settings: [String: Any] = [:]
    @Published private(set) var groups: [DeviceKind: [AssignmentGroup]] = [:]
    @Published private(set) var status: EngineStatus = .active
    @Published var errorMessage: String?

    private var observers: [NSObjectProtocol] = []

    init(store: JTSettingsStore, engine: JTEngineController) {
        self.store = store
        self.engine = engine
        let center = NotificationCenter.default
        for (name, object) in [
            (NSNotification.Name.JTSettingsStoreDidChange, store as AnyObject),
            (NSNotification.Name.JTEngineStateDidChange, engine as AnyObject),
        ] {
            observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func refresh() {
        settings = store.allSettings()
        var newGroups: [DeviceKind: [AssignmentGroup]] = [:]
        for kind in DeviceKind.allCases {
            newGroups[kind] = loadGroups(kind)
        }
        groups = newGroups
        status = currentStatus()
    }

    private func loadGroups(_ kind: DeviceKind) -> [AssignmentGroup] {
        let applications: [[String: Any]]
        do {
            applications = try store.commands(forKey: kind.commandsKey)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
        var result: [AssignmentGroup] = []
        var nextID = 0
        for application in applications {
            let name = application["Application"] as? String ?? "Unknown Application"
            let path = application["Path"] as? String ?? ""
            let commands = application["Gestures"] as? [[String: Any]] ?? []
            var assignments: [Assignment] = []
            for command in commands {
                assignments.append(Assignment(id: nextID, application: name, path: path, command: command))
                nextID += 1
            }
            if let index = result.firstIndex(where: { $0.application == name }) {
                result[index].assignments += assignments
            } else {
                result.append(AssignmentGroup(application: name, path: path, assignments: assignments))
            }
        }
        // The store keeps an application entry after its last gesture is
        // removed; there is nothing to show for it. Keep the catch-all group
        // first, then apps alphabetically.
        return result.filter { !$0.assignments.isEmpty }.sorted { left, right in
            if left.application == allApplicationsName { return true }
            if right.application == allApplicationsName { return false }
            return left.application.localizedCaseInsensitiveCompare(right.application) == .orderedAscending
        }
    }

    private func currentStatus() -> EngineStatus {
        if !store.isEnabled { return .paused }
        let accessibility = engine.accessibilityGranted
        let inputMonitoring = engine.inputMonitoringGranted
        if !accessibility && !inputMonitoring {
            return .needsPermission("Allow Jitouch Modern in Accessibility and Input Monitoring.")
        }
        if !accessibility { return .needsPermission("Allow Jitouch Modern in Accessibility.") }
        if !inputMonitoring { return .needsPermission("Allow Jitouch Modern in Input Monitoring.") }
        if !engine.isRunning { return .stopped }
        return .active
    }

    // MARK: Values

    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        (settings[key] as? NSNumber)?.boolValue ?? defaultValue
    }

    func integer(_ key: String, default defaultValue: Int) -> Int {
        (settings[key] as? NSNumber)?.intValue ?? defaultValue
    }

    func double(_ key: String, default defaultValue: Double) -> Double {
        (settings[key] as? NSNumber)?.doubleValue ?? defaultValue
    }

    func boolBinding(_ key: String, default defaultValue: Bool) -> Binding<Bool> {
        Binding(get: { self.bool(key, default: defaultValue) },
                set: { self.store.setBool($0, forKey: key) })
    }

    func integerBinding(_ key: String, default defaultValue: Int) -> Binding<Int> {
        Binding(get: { self.integer(key, default: defaultValue) },
                set: { self.store.setInteger($0, forKey: key) })
    }

    var isEnabled: Bool { store.isEnabled }

    var enabledBinding: Binding<Bool> {
        Binding(get: { self.store.isEnabled },
                set: { self.store.isEnabled = $0 })
    }

    var dragProtectionOn: Bool {
        bool(JTNativeThreeFingerDragProtectionKey, default: true)
    }

    func groups(for kind: DeviceKind) -> [AssignmentGroup] {
        groups[kind] ?? []
    }

    // MARK: Login item

    /// `make install` registers its own LaunchAgent; the login item is for
    /// people who downloaded the app instead.
    var installerLaunchAgentPresent: Bool {
        let path = ("~/Library/LaunchAgents/com.jitouch.JitouchModern.agent.plist" as NSString)
            .expandingTildeInPath
        return FileManager.default.fileExists(atPath: path)
    }

    var launchAtLoginStatus: SMAppService.Status { SMAppService.mainApp.status }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(get: {
            let status = self.launchAtLoginStatus
            return status == .enabled || status == .requiresApproval
        }, set: { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                self.errorMessage = "Couldn't change Open at Login: \(error.localizedDescription)"
            }
            self.objectWillChange.send()
        })
    }

    // MARK: Actions

    func retryEngine() {
        engine.retryAfterPermissionChange()
        refresh()
    }

    func openPrivacySettings() {
        let anchor = engine.inputMonitoringGranted ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    func setEnabled(_ enabled: Bool, for assignment: Assignment, kind: DeviceKind) {
        if enabled && AssignmentRules.isBlockedByDragProtection(assignment.gesture, kind: kind,
                                                               protectionOn: dragProtectionOn) {
            errorMessage = AssignmentRules.dragConflictMessage(for: assignment.gesture)
            return
        }
        if enabled && AssignmentRules.requiresAllApplications(assignment.gesture, kind: kind) &&
            assignment.application != allApplicationsName {
            errorMessage = AssignmentRules.allApplicationsMessage(for: assignment.gesture)
            return
        }
        perform {
            try store.setCommandEnabled(enabled, forApplication: assignment.application,
                                        gesture: assignment.gesture, forKey: kind.commandsKey)
        }
    }

    func delete(_ assignment: Assignment, kind: DeviceKind) {
        perform {
            try store.removeCommand(forApplication: assignment.application,
                                    gesture: assignment.gesture, forKey: kind.commandsKey)
        }
    }

    @discardableResult
    func perform(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            errorMessage = error.localizedDescription
            refresh()
            return false
        }
    }
}
