import SwiftUI
import AppKit

class SelectAllTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        DispatchQueue.main.async {
            self.currentEditor()?.selectAll(nil)
        }
    }
}

struct SelectAllTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> SelectAllTextField {
        let textField = SelectAllTextField()
        textField.placeholderString = placeholder
        textField.alignment = .center
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.stringValue = text
        applyTextColor(to: textField)
        return textField
    }

    func updateNSView(_ nsView: SelectAllTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        applyTextColor(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder)
    }

    private func applyTextColor(to textField: NSTextField) {
        textField.textColor = text == placeholder ? .placeholderTextColor : .labelColor
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        let placeholder: String

        init(text: Binding<String>, placeholder: String) {
            self.text = text
            self.placeholder = placeholder
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text.wrappedValue = textField.stringValue
                textField.textColor = textField.stringValue == placeholder ? .placeholderTextColor : .labelColor
            }
        }
    }
}

struct SoundPopUpButton: NSViewRepresentable {
    @Binding var selectedSound: String
    let sounds: [String]

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .small
        button.target = context.coordinator
        button.action = #selector(Coordinator.soundChanged(_:))
        button.autoenablesItems = false
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selectedSound = $selectedSound
        rebuildMenu(for: button, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedSound: $selectedSound)
    }

    private func rebuildMenu(for button: NSPopUpButton, coordinator: Coordinator) {
        button.removeAllItems()
        button.menu?.minimumWidth = max(button.bounds.width, 150)

        let selectedItem = NSMenuItem(title: "\(selectedSound)   ", action: nil, keyEquivalent: "")
        selectedItem.state = .on
        selectedItem.representedObject = selectedSound
        selectedItem.target = coordinator
        selectedItem.action = #selector(Coordinator.soundMenuItemSelected(_:))
        button.menu?.addItem(selectedItem)
        button.menu?.addItem(.separator())

        for sound in sounds where sound != selectedSound {
            let item = NSMenuItem(title: "\(sound)   ", action: nil, keyEquivalent: "")
            item.representedObject = sound
            item.target = coordinator
            item.action = #selector(Coordinator.soundMenuItemSelected(_:))
            button.menu?.addItem(item)
        }

        button.selectItem(at: 0)
    }

    class Coordinator: NSObject {
        var selectedSound: Binding<String>

        init(selectedSound: Binding<String>) {
            self.selectedSound = selectedSound
        }

        @objc func soundChanged(_ sender: NSPopUpButton) {
            guard let sound = sender.selectedItem?.representedObject as? String else { return }
            selectedSound.wrappedValue = sound
        }

        @objc func soundMenuItemSelected(_ sender: NSMenuItem) {
            guard let sound = sender.representedObject as? String else { return }
            selectedSound.wrappedValue = sound
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var timerState: TimerState

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
            SettingsDivider()
                .padding(.horizontal, 20)

            if timerState.phase == .completed {
                CompletionView()
            } else if timerState.phase == .idle {
                NewFocusBlockView()
            } else {
                SessionView()
            }

        }
        .frame(width: 320)
    }
}

struct HeaderBar: View {
    private let websiteURL = URL(string: "https://oputtick.github.io/focus-mode")!
    private let feedbackURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfLZZatZ4KgezkacNFMsEipdeF4KRxKLsWfI6aboaQVMs13_Q/viewform")!

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Focus Mode \(version) (\(build))"
    }

    var body: some View {
        HStack {
            Text("Focus Mode")
                .font(.headline)

            Spacer()

            Menu {
                Button("About") {
                    NSWorkspace.shared.open(websiteURL)
                }
                Button("Send Feedback") {
                    NSWorkspace.shared.open(feedbackURL)
                }
                Divider()
                Button("Quit Focus Mode") {
                    NSApp.terminate(nil)
                }
                Divider()
                Button(appVersion) {}
                    .disabled(true)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 0.5)
    }
}

struct NewFocusBlockView: View {
    @EnvironmentObject var timerState: TimerState
    @State private var focus: String = ""
    @State private var outcome: String = ""
    @State private var hoursText: String = "00"
    @State private var minutesText: String = "00"
    @State private var secondsText: String = "00"
    @FocusState private var focusFieldActive: Bool

    private var totalSeconds: Int {
        let h = max(0, min(23, Int(hoursText) ?? 0))
        let m = max(0, min(59, Int(minutesText) ?? 0))
        let s = max(0, min(59, Int(secondsText) ?? 0))
        return h * 3600 + m * 60 + s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Focus")
                    .font(.subheadline)
                TextField("What are you working on?", text: $focus)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusFieldActive)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Outcome")
                    .font(.subheadline)
                TextField("What will you deliver?", text: $outcome)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Duration")
                    .font(.subheadline)

                Spacer()

                HStack(spacing: 4) {
                    SelectAllTextFieldRepresentable(text: $hoursText, placeholder: "00")
                        .frame(width: 40, height: 22)
                    Text("hr")
                        .foregroundColor(.secondary)
                    SelectAllTextFieldRepresentable(text: $minutesText, placeholder: "00")
                        .frame(width: 40, height: 22)
                    Text("min")
                        .foregroundColor(.secondary)
                    SelectAllTextFieldRepresentable(text: $secondsText, placeholder: "00")
                        .frame(width: 40, height: 22)
                    Text("sec")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsDivider()

            HStack {
                Text("Sound")
                    .font(.subheadline)

                Spacer()

                HStack {
                    SoundPopUpButton(
                        selectedSound: $timerState.selectedSound,
                        sounds: TimerState.availableSounds
                    )
                    .frame(width: 150, height: 22)

                    Button(action: {
                        AlarmPlayer.shared.previewSound(named: timerState.selectedSound)
                    }) {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("Preview sound")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsDivider()

            HStack {
                Text("Notify at halfway point")
                    .font(.subheadline)

                Spacer()

                Toggle("", isOn: $timerState.halfwayReminderEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                timerState.focus = focus
                timerState.outcome = outcome
                timerState.startWithSeconds(totalSeconds)
            }) {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(focus.isEmpty || totalSeconds == 0)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusFieldActive = true
            }
        }
    }
}

struct SessionView: View {
    @EnvironmentObject var timerState: TimerState

    var body: some View {
        VStack(spacing: 16) {
            Text(timerState.displayTime)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundColor(timerState.isInFinalCountdown ? .red : .primary)

            SettingsDivider()

            VStack(alignment: .leading, spacing: 8) {
                Label(timerState.focus, systemImage: "target")
                    .font(.subheadline)

                if !timerState.outcome.isEmpty {
                    Label(timerState.outcome, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsDivider()

            HStack(spacing: 12) {
                Button(action: { timerState.reset() }) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if timerState.phase == .running {
                    Button(action: { timerState.pause() }) {
                        Text("Pause").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if timerState.phase == .paused {
                    Button(action: { timerState.resume() }) {
                        Text("Resume").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(20)
    }
}

struct CompletionView: View {
    @EnvironmentObject var timerState: TimerState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("Focus Block Complete")
                .font(.headline)

            Text("Time to deliver what you committed to.")
                .font(.caption)
                .foregroundColor(.secondary)

            SettingsDivider()

            VStack(alignment: .leading, spacing: 8) {
                Label(timerState.focus, systemImage: "target")
                    .font(.subheadline)

                if !timerState.outcome.isEmpty {
                    Label(timerState.outcome, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsDivider()

            HStack(spacing: 12) {
                Button(action: {
                    timerState.reset()
                    NSApp.keyWindow?.close()
                }) {
                    Text("Close").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: { timerState.reset() }) {
                    Text("New Focus Block").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(20)
        .onAppear {
            AlarmPlayer.shared.stopLooping()
        }
    }
}
