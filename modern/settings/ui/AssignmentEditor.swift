import AppKit
import SwiftUI

struct AppChoice: Hashable {
    let name: String
    let path: String

    static let all = AppChoice(name: allApplicationsName, path: "")
    static let other = AppChoice(name: "\u{0}other", path: "")
}

enum ActionChoice: Hashable {
    case builtIn(String)
    case shortcut
    case file
    case url
}

/// Installed applications, scanned once per launch off the main thread.
@MainActor
final class InstalledApplications: ObservableObject {
    static let shared = InstalledApplications()
    @Published private(set) var apps: [AppChoice] = []
    private var loading = false

    func load() {
        guard apps.isEmpty, !loading else { return }
        loading = true
        Task.detached(priority: .userInitiated) {
            let found = Self.scan()
            await MainActor.run {
                self.apps = found
                self.loading = false
            }
        }
    }

    nonisolated private static func scan() -> [AppChoice] {
        let roots = ["/Applications", "/System/Applications",
                     ("~/Applications" as NSString).expandingTildeInPath]
        var seen = Set<String>()
        var result: [AppChoice] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: root, isDirectory: true),
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                guard (try? url.resourceValues(forKeys: [.isApplicationKey]))?.isApplication == true,
                      seen.insert(url.path).inserted else { continue }
                result.append(AppChoice(name: displayName(of: url), path: url.path))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated static func displayName(of url: URL) -> String {
        let bundle = Bundle(url: url)
        return bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            url.deletingPathExtension().lastPathComponent
    }
}

/// Holds the AppKit shortcut recorder so its recorded value survives re-renders.
final class ShortcutRecorderBox: ObservableObject {
    let field: JTShortcutRecorderField = {
        let field = JTShortcutRecorderField(frame: .zero)
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        return field
    }()
}

struct ShortcutRecorderView: NSViewRepresentable {
    let field: JTShortcutRecorderField

    func makeNSView(context: Context) -> JTShortcutRecorderField { field }
    func updateNSView(_ nsView: JTShortcutRecorderField, context: Context) {}
}

struct AssignmentEditor: View {
    @ObservedObject var model: SettingsModel
    let kind: DeviceKind
    let original: Assignment?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var installed = InstalledApplications.shared
    @StateObject private var recorder = ShortcutRecorderBox()

    @State private var application: AppChoice = .all
    @State private var extraApps: [AppChoice] = []
    @State private var gesture = ""
    @State private var action: ActionChoice = .builtIn("-")
    @State private var filePath = ""
    @State private var urlText = ""
    @State private var enabled = true
    @State private var validationMessage: String?
    @State private var confirmingReplace = false
    @State private var confirmingDelete = false
    @State private var loaded = false

    private var isNew: Bool { original == nil }
    private var requiredAction: String? { AssignmentRules.requiredAction(for: gesture, kind: kind) }

    private var applicationOptions: [AppChoice] {
        var options: [AppChoice] = []
        var names = Set<String>()
        for choice in extraApps + model.groups(for: kind).map({ AppChoice(name: $0.application, path: $0.path) })
            + installed.apps where names.insert(choice.name).inserted && choice.name != allApplicationsName {
            options.append(choice)
        }
        return options.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var gestureOptions: [String] {
        var options = kind.gestureCatalog
        if let old = original?.gesture, !old.isEmpty, !options.contains(old) { options.append(old) }
        return options
    }

    private var actionOptions: [String] {
        var options = kind.builtInActions
        if case .builtIn(let name) = action, !options.contains(name) { options.insert(name, at: 0) }
        if let required = requiredAction, !options.contains(required) { options.insert(required, at: 0) }
        return options
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GestureGlyph(gesture: gesture, kind: kind)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.gradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isNew ? "New Assignment" : "Edit Assignment")
                        .font(.headline)
                    Text("\(kind.title) · \(application == .other ? allApplicationsName : application.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 4)

            Form {
                Section {
                    Picker("Application", selection: $application) {
                        Label(allApplicationsName, systemImage: "square.grid.2x2").tag(AppChoice.all)
                        Divider()
                        ForEach(applicationOptions, id: \.self) { choice in
                            Text(choice.name).tag(choice)
                        }
                        Divider()
                        Text("Other App…").tag(AppChoice.other)
                    }
                    .disabled(!isNew)
                    Picker("Gesture", selection: $gesture) {
                        ForEach(gestureOptions, id: \.self) { name in
                            Label(name, systemImage: AssignmentRules.symbol(for: name, kind: kind)).tag(name)
                        }
                    }
                    .disabled(requiredAction != nil && !isNew)
                }

                Section {
                    Picker("Action", selection: $action) {
                        ForEach(actionOptions, id: \.self) { name in
                            Text(AssignmentRules.actionTitle(name)).tag(ActionChoice.builtIn(name))
                        }
                        Divider()
                        Text("Keyboard Shortcut").tag(ActionChoice.shortcut)
                        Text("Open File").tag(ActionChoice.file)
                        Text("Open Website").tag(ActionChoice.url)
                    }
                    .disabled(requiredAction != nil)

                    switch action {
                    case .shortcut:
                        LabeledContent("Shortcut") {
                            ShortcutRecorderView(field: recorder.field)
                                .frame(width: 180, height: 22)
                        }
                    case .file:
                        LabeledContent("File") {
                            HStack {
                                Text(filePath.isEmpty ? "None" : (filePath as NSString).lastPathComponent)
                                    .foregroundStyle(filePath.isEmpty ? .secondary : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button("Choose…", action: chooseFile)
                            }
                        }
                    case .url:
                        TextField("Website", text: $urlText, prompt: Text("https://example.com"))
                    case .builtIn:
                        EmptyView()
                    }

                    Toggle("Enabled", isOn: $enabled)
                } footer: {
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if kind == .trackpad && model.dragProtectionOn {
                        Text("Three-finger drag protection is on, so moving and clicking three-finger gestures stay off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if let original {
                    Button("Delete", role: .destructive) { confirmingDelete = true }
                        .confirmationDialog("Delete this assignment?", isPresented: $confirmingDelete) {
                            Button("Delete", role: .destructive) {
                                model.delete(original, kind: kind)
                                dismiss()
                            }
                        }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: loadOriginal)
        .onChange(of: application) { newValue in
            if newValue == .other { chooseOtherApp() }
        }
        .onChange(of: gesture) { newValue in
            if let required = AssignmentRules.requiredAction(for: newValue, kind: kind) {
                action = .builtIn(required)
            }
        }
        .alert("Replace the existing assignment?", isPresented: $confirmingReplace) {
            Button("Replace", role: .destructive) { commit(replacingDuplicate: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(application.name) already has an assignment for \(gesture).")
        }
    }

    // MARK: Loading

    private func loadOriginal() {
        guard !loaded else { return }
        loaded = true
        installed.load()
        recorder.field.recordingHandler = { _ in
            if requiredAction == nil { action = .shortcut }
        }
        guard let original else {
            gesture = kind.gestureCatalog.first ?? ""
            recorder.field.clearShortcut()
            return
        }
        let command = original.command
        application = AppChoice(name: original.application, path: original.path)
        extraApps = [application]
        gesture = original.gesture
        enabled = original.isEnabled
        let isAction = (command["IsAction"] as? NSNumber)?.boolValue ?? false
        if !isAction {
            action = .shortcut
            recorder.field.setModifierFlags(
                (command["ModifierFlags"] as? NSNumber)?.uintValue ?? 0,
                keyCode: CGKeyCode((command["KeyCode"] as? NSNumber)?.uint16Value ?? 0))
        } else if let path = command["OpenFilePath"] as? String {
            action = .file
            filePath = path
        } else if let url = command["OpenURL"] as? String {
            action = .url
            urlText = url
        } else {
            action = .builtIn(command["Command"] as? String ?? "-")
        }
        if isAction { recorder.field.clearShortcut() }
    }

    private func chooseOtherApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose App"
        guard panel.runModal() == .OK, let url = panel.url,
              Bundle(url: url)?.bundleIdentifier?.isEmpty == false else {
            application = .all
            return
        }
        let choice = AppChoice(name: InstalledApplications.displayName(of: url), path: url.path)
        if !extraApps.contains(choice) { extraApps.append(choice) }
        application = choice
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url { filePath = url.path }
    }

    // MARK: Saving

    private func save() {
        validationMessage = nil
        if gesture.isEmpty { return fail("Choose a gesture.") }
        if AssignmentRules.requiresAllApplications(gesture, kind: kind) && application != .all {
            return fail(AssignmentRules.allApplicationsMessage(for: gesture))
        }
        if enabled && AssignmentRules.isBlockedByDragProtection(gesture, kind: kind,
                                                                protectionOn: model.dragProtectionOn) {
            return fail(AssignmentRules.dragConflictMessage(for: gesture))
        }
        if duplicate() != nil {
            confirmingReplace = true
            return
        }
        commit(replacingDuplicate: false)
    }

    private func fail(_ message: String) {
        validationMessage = message
    }

    private func duplicate() -> Assignment? {
        model.groups(for: kind)
            .flatMap(\.assignments)
            .first { $0.application == application.name && $0.gesture == gesture && $0.id != original?.id }
    }

    private func buildCommand() -> [String: Any]? {
        var command = original?.command ?? [:]
        command["Gesture"] = gesture
        command["Enable"] = NSNumber(value: enabled)
        command.removeValue(forKey: "OpenFilePath")
        command.removeValue(forKey: "OpenURL")
        let chosen = requiredAction.map(ActionChoice.builtIn) ?? action
        switch chosen {
        case .shortcut:
            let field = recorder.field
            let hadShortcut = original.map { !(($0.command["IsAction"] as? NSNumber)?.boolValue ?? false) } ?? false
            if !field.hasRecordedShortcut && !hadShortcut {
                fail("Click the shortcut field and press the key combination to use.")
                return nil
            }
            if field.hasRecordedShortcut {
                if field.keyCode >= 128 {
                    fail("That key can't be stored in the Jitouch shortcut format.")
                    return nil
                }
                command["Command"] = field.stringValue
                command["ModifierFlags"] = NSNumber(value: field.modifierFlags)
                command["KeyCode"] = NSNumber(value: field.keyCode)
            }
            command["IsAction"] = NSNumber(value: false)
        case .file:
            if filePath.isEmpty {
                fail("Choose a file to open.")
                return nil
            }
            command["Command"] = "Open File"
            command["IsAction"] = NSNumber(value: true)
            command["ModifierFlags"] = NSNumber(value: 0)
            command["KeyCode"] = NSNumber(value: 0)
            command["OpenFilePath"] = filePath
        case .url:
            guard let url = URL(string: urlText.trimmingCharacters(in: .whitespaces)),
                  let scheme = url.scheme, !scheme.isEmpty else {
                fail("Enter a complete web address, including https://.")
                return nil
            }
            command["Command"] = "Open Website"
            command["IsAction"] = NSNumber(value: true)
            command["ModifierFlags"] = NSNumber(value: 0)
            command["KeyCode"] = NSNumber(value: 0)
            command["OpenURL"] = url.absoluteString
        case .builtIn(let name):
            command["Command"] = name
            command["IsAction"] = NSNumber(value: true)
            command["ModifierFlags"] = NSNumber(value: 0)
            command["KeyCode"] = NSNumber(value: 0)
        }
        return command
    }

    private func commit(replacingDuplicate: Bool) {
        guard let command = buildCommand() else { return }
        let key = kind.commandsKey
        let existing = replacingDuplicate ? duplicate() : nil
        // Renaming onto another row's gesture removes that row first. The store
        // has no multi-row transaction, so restore it if the upsert fails.
        let renamedOntoDuplicate = existing != nil && original != nil && original?.gesture != gesture
        if renamedOntoDuplicate, let existing,
           !model.perform({ try model.store.removeCommand(forApplication: existing.application,
                                                         gesture: existing.gesture, forKey: key) }) {
            return
        }
        let saved = model.perform {
            try model.store.upsertCommand(command, application: application.name,
                                          path: application.path,
                                          replacingGesture: original?.gesture, forKey: key)
        }
        if !saved {
            if renamedOntoDuplicate, let existing {
                try? model.store.upsertCommand(existing.command, application: existing.application,
                                               path: existing.path, replacingGesture: nil, forKey: key)
            }
            return
        }
        dismiss()
    }
}
