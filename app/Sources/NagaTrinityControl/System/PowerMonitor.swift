import AppKit
import Foundation
import os

@MainActor
final class PowerMonitor {
    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "PowerMonitor")
    private weak var store: AppStore?
    private var observers: [NSObjectProtocol] = []

    func start(store: AppStore) {
        self.store = store
        stop()

        let dnc = DistributedNotificationCenter.default()
        observers.append(
            dnc.addObserver(
                forName: NSNotification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleLockOrSleep()
                }
            }
        )
        observers.append(
            dnc.addObserver(
                forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleUnlockOrWake()
                }
            }
        )

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleLockOrSleep()
                }
            }
        )
        observers.append(
            workspace.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleUnlockOrWake()
                }
            }
        )
    }

    func stop() {
        let dnc = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in observers {
            dnc.removeObserver(observer)
            workspace.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func handleLockOrSleep() async {
        guard store != nil else { return }
        let settings = await CoreClient.getSettings()
        if settings.rgbOffOnLock {
            logger.info("lock/sleep → RGB off")
            _ = await CoreClient.setRgbOff()
        }
    }

    private func handleUnlockOrWake() async {
        guard let store else { return }
        logger.info("unlock/wake → restore RGB after 600ms")
        try? await Task.sleep(nanoseconds: 600_000_000)
        let latest = await CoreClient.readStore()
        store.store = latest
        await store.previewActiveRgb()
    }

    deinit {
        // Observers removed on stop(); deinit may run off MainActor.
    }
}
