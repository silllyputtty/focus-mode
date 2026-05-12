import Foundation
import Combine

enum TimerPhase {
    case idle
    case running
    case paused
    case completed
}

class TimerState: ObservableObject {
    @Published var phase: TimerPhase = .idle
    @Published var secondsRemaining: Int = 0

    @Published var focus: String = ""
    @Published var outcome: String = ""

    @Published var showCompletionAlert: Bool = false
    @Published var selectedSound: String = "Submarine"

    @Published var halfwayReminderEnabled: Bool = false
    private var halfwayFired: Bool = false

    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
        "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink"
    ]

    var originalDuration: Int = 0
    private var timer: AnyCancellable?

    var displayTime: String {
        let h = secondsRemaining / 3600
        let m = (secondsRemaining % 3600) / 60
        let s = secondsRemaining % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var menuBarTitle: String {
        switch phase {
        case .idle:
            return ""
        case .running:
            return displayTime
        case .paused:
            return "⏸ \(displayTime)"
        case .completed:
            return "✓"
        }
    }

    var isInFinalCountdown: Bool {
        phase == .running && secondsRemaining <= 60 && secondsRemaining > 0
    }

    func startWithSeconds(_ seconds: Int) {
        guard !focus.isEmpty else { return }
        guard seconds > 0 else { return }
        originalDuration = seconds
        secondsRemaining = originalDuration
        halfwayFired = false
        phase = .running
        startTimer()
    }

    func pause() {
        phase = .paused
        stopTimer()
    }

    func resume() {
        phase = .running
        startTimer()
    }

    func complete() {
        phase = .completed
        AlarmPlayer.shared.stopLooping()
    }

    func reset() {
        phase = .idle
        secondsRemaining = 0
        focus = ""
        outcome = ""
        showCompletionAlert = false
        stopTimer()
        AlarmPlayer.shared.stopLooping()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func checkReminders() {
        let elapsed = originalDuration - secondsRemaining

        if halfwayReminderEnabled && !halfwayFired {
            let halfway = originalDuration / 2
            if elapsed >= halfway && halfway > 0 {
                halfwayFired = true
                NotificationManager.shared.sendReminderNotification(
                    title: "Halfway there",
                    body: "\(displayTime) remaining \u{2014} \(focus)"
                )
            }
        }

    }

    private func tick() {
        guard secondsRemaining > 0 else { return }
        secondsRemaining -= 1

        checkReminders()

        if secondsRemaining == 0 {
            stopTimer()
            phase = .completed
            showCompletionAlert = true
            AlarmPlayer.shared.startLooping(named: selectedSound)
            NotificationManager.shared.sendCompletionNotification(
                focus: focus,
                outcome: outcome
            )
        }
    }
}
