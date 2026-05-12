import SwiftUI
import AppKit
import Darwin
import MenuBarExtraAccess

final class MenuBarPresentation: ObservableObject {
    static let shared = MenuBarPresentation()
    @Published var isPresented: Bool = false
    private init() {}
}

enum SingleInstanceLock {
    private static var lockFileDescriptor: Int32 = -1

    static func acquire() -> Bool {
        let lockURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("com.sillyputtty.FocusMode.lock")

        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return false }

        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
            lockFileDescriptor = descriptor
            return true
        }

        close(descriptor)
        return false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        NotificationManager.shared.requestPermission()
    }
}

@main
struct FocusModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var timerState = TimerState()
    @ObservedObject private var menuPresentation = MenuBarPresentation.shared

    init() {
        guard SingleInstanceLock.acquire() else {
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(timerState)
                .onReceive(NotificationCenter.default.publisher(for: .focusBlockNotificationTapped)) { _ in
                    timerState.complete()
                }
        } label: {
            Group {
                if timerState.phase == .idle || timerState.phase == .completed {
                    Image(systemName: "timer")
                } else {
                    Text(timerState.menuBarTitle)
                }
            }
            .frame(minWidth: 60, alignment: .center)
        }
        .menuBarExtraAccess(isPresented: $menuPresentation.isPresented)
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}
