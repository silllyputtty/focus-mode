import AVFoundation
import AppKit

class AlarmPlayer {
    static let shared = AlarmPlayer()

    private var player: AVAudioPlayer?
    private var isLooping: Bool = false

    func playSound(named name: String) {
        if let url = findSystemSound(named: name) {
            play(url: url, loop: false)
        } else {
            NSSound.beep()
        }
    }

    func startLooping(named name: String) {
        guard !isLooping else { return }
        isLooping = true
        if let url = findSystemSound(named: name) {
            play(url: url, loop: true)
        }
    }

    func stopLooping() {
        isLooping = false
        player?.stop()
        player = nil
    }

    func previewSound(named name: String) {
        if let url = findSystemSound(named: name) {
            play(url: url, loop: false)
        }
    }

    private func findSystemSound(named name: String) -> URL? {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    private func play(url: URL, loop: Bool) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1.0
            player?.numberOfLoops = loop ? -1 : 0
            player?.enableRate = true
            player?.rate = 1.5
            player?.prepareToPlay()
            player?.play()
        } catch {
            NSSound.beep()
        }
    }
}
