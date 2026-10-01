import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case trackpad
    case magicMouse
    case drawing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .trackpad: return "Trackpad"
        case .magicMouse: return "Magic Mouse"
        case .drawing: return "Drawing"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .trackpad: return "rectangle.and.hand.point.up.left.fill"
        case .magicMouse: return "magicmouse.fill"
        case .drawing: return "scribble.variable"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .trackpad: return .blue
        case .magicMouse: return .indigo
        case .drawing: return .orange
        }
    }

    var device: DeviceKind? {
        switch self {
        case .general: return nil
        case .trackpad: return .trackpad
        case .magicMouse: return .magicMouse
        case .drawing: return .drawing
        }
    }
}

/// A rounded, filled icon like the ones in System Settings' sidebar.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(tint.gradient)
            )
    }
}

struct SettingsRootView: View {
    @ObservedObject var model: SettingsModel
    @AppStorage("SettingsPane") private var storedPane = SettingsPane.general.rawValue

    private var selection: SettingsPane? {
        SettingsPane(rawValue: storedPane) ?? .general
    }

    private var selectionBinding: Binding<SettingsPane?> {
        Binding(get: { selection }, set: { if let pane = $0 { storedPane = pane.rawValue } })
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: selectionBinding) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    SettingsIcon(symbol: pane.symbol, tint: pane.tint)
                }
                .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:
                    GeneralPane(model: model)
                case .trackpad:
                    DevicePane(model: model, kind: .trackpad)
                case .magicMouse:
                    DevicePane(model: model, kind: .magicMouse)
                case .drawing:
                    DevicePane(model: model, kind: .drawing)
                }
            }
        }
        .background(WindowTitle(title: (selection ?? .general).title))
        .frame(minWidth: 720, minHeight: 520)
        .alert("Jitouch", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Jitouch")
                            .font(.title2.weight(.semibold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(model.status.color)
                                .frame(width: 8, height: 8)
                            Text(model.status.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("Enable gestures", isOn: model.enabledBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.large)
                }
                .padding(.vertical, 6)
            }

            if model.status.needsAttention {
                Section {
                    Label {
                        Text(model.status.detail ?? "")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Open Privacy & Security…") { model.openPrivacySettings() }
                        Button("Retry") { model.retryEngine() }
                    }
                }
            }

            Section("Gestures") {
                CommittingSlider(
                    title: "Tap speed",
                    value: 0.5 - model.double("ClickSpeed", default: 0.25),
                    range: 0.1...0.4, step: 0.03,
                    minimumLabel: "Slow", maximumLabel: "Fast"
                ) { model.store.setDouble(0.5 - $0, forKey: "ClickSpeed") }
                CommittingSlider(
                    title: "Sensitivity",
                    value: model.double("Sensitivity", default: 4.6666),
                    range: 4.0...10.0, step: 6.0 / 9.0,
                    minimumLabel: "Soft", maximumLabel: "Firm"
                ) { model.store.setDouble($0, forKey: "Sensitivity") }
            }
            .disabled(!model.isEnabled)

            Section {
                Toggle("Show in menu bar", isOn: model.boolBinding("ShowIcon", default: true))
                Picker("Logging", selection: model.integerBinding("LogLevel", default: 0)) {
                    Text("Quiet").tag(-1)
                    Text("Default").tag(0)
                    Text("Info").tag(1)
                    Text("Debug").tag(2)
                }
            } footer: {
                Text("Press ⌃⌥⌘⎋ at any time to pause all gestures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Writes only when the drag ends, so the engine reloads once per change.
struct CommittingSlider: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minimumLabel: String
    let maximumLabel: String
    let commit: (Double) -> Void
    @State private var draft: Double?

    var body: some View {
        Slider(
            value: Binding(get: { draft ?? value }, set: { draft = $0 }),
            in: range, step: step
        ) {
            Text(title)
        } minimumValueLabel: {
            Text(minimumLabel).font(.caption).foregroundStyle(.secondary)
        } maximumValueLabel: {
            Text(maximumLabel).font(.caption).foregroundStyle(.secondary)
        } onEditingChanged: { editing in
            if !editing, let final = draft {
                commit(final)
                draft = nil
            }
        }
    }
}

// MARK: - Devices

struct DevicePane: View {
    @ObservedObject var model: SettingsModel
    let kind: DeviceKind
    @State private var search = ""
    @State private var editing: EditorRequest?
    @State private var confirmingProtectionOff = false

    var body: some View {
        Form {
            deviceSection
            AssignmentSections(model: model, kind: kind, search: search) { assignment in
                editing = EditorRequest(assignment: assignment)
            }
        }
        .formStyle(.grouped)
        .searchable(text: $search, placement: .toolbar, prompt: "Search gestures")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = EditorRequest(assignment: nil)
                } label: {
                    Label("Add Assignment", systemImage: "plus")
                }
                .help("Add a gesture assignment")
            }
        }
        .sheet(item: $editing) { request in
            AssignmentEditor(model: model, kind: kind, original: request.assignment)
        }
        .confirmationDialog("Turn off Three-Finger Drag Protection?",
                            isPresented: $confirmingProtectionOff) {
            Button("Turn Off Protection", role: .destructive) {
                model.store.setBool(false, forKey: JTNativeThreeFingerDragProtectionKey)
            }
            Button("Keep Protection", role: .cancel) {}
        } message: {
            Text("Turn off macOS three-finger dragging first. Running both can break dragging and clicks.")
        }
    }

    @ViewBuilder
    private var deviceSection: some View {
        switch kind {
        case .trackpad:
            Section {
                Toggle("Trackpad gestures", isOn: model.boolBinding("enTPAll", default: true))
                Group {
                    Picker("Hand", selection: model.integerBinding("Handed", default: 0)) {
                        Text("Right").tag(0)
                        Text("Left").tag(1)
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: Binding(
                        get: { model.dragProtectionOn },
                        set: { on in
                            if on {
                                model.store.setBool(true, forKey: JTNativeThreeFingerDragProtectionKey)
                            } else {
                                confirmingProtectionOff = true
                            }
                        }
                    )) {
                        Text("Three-finger drag protection")
                        Text("Keeps macOS three-finger dragging working. Three-finger taps stay available.")
                    }
                }
                .disabled(!model.bool("enTPAll", default: true))
            }
            .disabled(!model.isEnabled)
        case .magicMouse:
            Section {
                Toggle("Magic Mouse gestures", isOn: model.boolBinding("enMMAll", default: true))
                Picker("Hand", selection: model.integerBinding("MMHanded", default: 0)) {
                    Text("Right").tag(0)
                    Text("Left").tag(1)
                }
                .pickerStyle(.segmented)
                .disabled(!model.bool("enMMAll", default: true))
            }
            .disabled(!model.isEnabled)
        case .drawing:
            Section {
                Toggle("Draw on trackpad", isOn: model.boolBinding("enCharRegTP", default: false))
                Toggle("Draw on Magic Mouse", isOn: model.boolBinding("enCharRegMM", default: false))
            } footer: {
                Text("Draw a letter or stroke to run its assigned action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!model.isEnabled)
        }
    }
}

struct EditorRequest: Identifiable {
    let id = UUID()
    let assignment: Assignment?
}

struct AssignmentSections: View {
    @ObservedObject var model: SettingsModel
    let kind: DeviceKind
    let search: String
    let edit: (Assignment) -> Void
    @State private var pendingDelete: Assignment?

    private var filteredGroups: [AssignmentGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.groups(for: kind) }
        return model.groups(for: kind).compactMap { group in
            var filtered = group
            filtered.assignments = group.assignments.filter {
                $0.gesture.localizedCaseInsensitiveContains(query) ||
                    AssignmentRules.describe(command: $0.command).localizedCaseInsensitiveContains(query) ||
                    group.application.localizedCaseInsensitiveContains(query)
            }
            return filtered.assignments.isEmpty ? nil : filtered
        }
    }

    var body: some View {
        let groups = filteredGroups
        if groups.isEmpty {
            Section {
                Text(search.isEmpty ? "No gestures assigned yet. Click + to add one." : "No matching gestures.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        ForEach(groups) { group in
            Section {
                ForEach(group.assignments) { assignment in
                    AssignmentRow(model: model, kind: kind, assignment: assignment, edit: edit) {
                        pendingDelete = assignment
                    }
                }
            } header: {
                ApplicationHeader(name: group.application, path: group.path)
            }
        }
        .confirmationDialog(
            "Delete this assignment?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { assignment in
            Button("Delete", role: .destructive) { model.delete(assignment, kind: kind) }
        } message: { assignment in
            Text("\(assignment.application) — \(assignment.gesture)")
        }
    }
}

struct ApplicationHeader: View {
    let name: String
    let path: String

    var body: some View {
        HStack(spacing: 6) {
            if name == allApplicationsName || path.isEmpty {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.secondary)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(name)
        }
    }
}

struct AssignmentRow: View {
    @ObservedObject var model: SettingsModel
    let kind: DeviceKind
    let assignment: Assignment
    let edit: (Assignment) -> Void
    let delete: () -> Void

    private var warning: String? {
        if AssignmentRules.isBlockedByDragProtection(assignment.gesture, kind: kind,
                                                     protectionOn: model.dragProtectionOn) {
            return "Paused by three-finger drag protection"
        }
        if AssignmentRules.requiresAllApplications(assignment.gesture, kind: kind) &&
            assignment.application != allApplicationsName {
            return "Works only under All Applications"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 10) {
            GestureGlyph(gesture: assignment.gesture, kind: kind)
                .foregroundStyle(assignment.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.gesture)
                if let warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 12)
            Text(AssignmentRules.describe(command: assignment.command))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Toggle("Enabled", isOn: Binding(
                get: { assignment.isEnabled },
                set: { model.setEnabled($0, for: assignment, kind: kind) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            Button {
                edit(assignment)
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .help("Edit")
        }
        .opacity(assignment.isEnabled ? 1 : 0.6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { edit(assignment) }
        .contextMenu {
            Button("Edit…") { edit(assignment) }
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }
}

/// A drawn letter shows the letter itself; everything else gets a symbol.
struct GestureGlyph: View {
    let gesture: String
    let kind: DeviceKind

    var body: some View {
        if kind == .drawing && gesture.count == 1 {
            Text(gesture)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        } else {
            Image(systemName: AssignmentRules.symbol(for: gesture, kind: kind))
                .font(.system(size: 13, weight: .medium))
        }
    }
}
