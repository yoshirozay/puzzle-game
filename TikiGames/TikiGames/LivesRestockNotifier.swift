import Foundation
import UserNotifications

/// Local "pool fully restocked" notification — offline, on-device only.
/// One fixed identifier; schedule replaces, never stacks. No APNs, no
/// badge, no categories. Decision math is pure so tests don't need the
/// notification center.
enum LivesRestockNotify {
    /// Stable request id — rescheduling cancels the prior request under
    /// the same id (UNUserNotificationCenter replace semantics).
    static let identifier = "tiki.lives.restocked"

    static let title = "LIVES FULL"
    static let body = "All five hearts are back. Time to play."

    /// Pure schedule plan — no UserNotifications traffic.
    enum Plan: Equatable {
        /// Fire once after this many wall-clock seconds.
        case schedule(seconds: Int)
        /// Drop any pending restock request (pool is full, or unauth).
        case cancel
    }

    /// Below cap → schedule at exactly `secondsUntilFull`; at cap / nil → cancel.
    static func plan(secondsUntilFull: Int?) -> Plan {
        guard let seconds = secondsUntilFull, seconds > 0 else { return .cancel }
        return .schedule(seconds: seconds)
    }

    /// Beat between the defeat panel landing and the system alert prompt —
    /// long enough that the panel reads as the reason for the ask.
    static let authorizationPromptDelay: TimeInterval = 2

    /// Whether a defeat should surface the one-time system alert prompt.
    ///
    /// Only when the defeat emptied the pool: that is the one moment the
    /// player is actually locked out, so the ask has something to offer.
    /// iOS shows this dialog once per install and never again, so a
    /// settled status (granted OR denied) must never re-ask, and tutorial
    /// defeats — which cost nothing — never spend it.
    static func shouldOfferAuthorization(
        lives: Int,
        status: UNAuthorizationStatus,
        duringTutorial: Bool
    ) -> Bool {
        lives == 0 && status == .notDetermined && !duringTutorial
    }
}

/// Owns all UserNotifications traffic for the restock banner. Call sites
/// stay free of UN types; inject a center for tests.
@MainActor
final class LivesRestockNotifier {
    static let shared = LivesRestockNotifier()

    /// Thin seam over UNUserNotificationCenter so schedule/cancel logic
    /// can be driven without the real framework in unit tests. MainActor
    /// so Swift 6 doesn't treat the existential as a cross-isolation hop.
    @MainActor
    protocol Center: AnyObject {
        func authorizationStatus() async -> UNAuthorizationStatus
        func requestAuthorization() async -> Bool
        func schedule(id: String, afterSeconds: TimeInterval, title: String, body: String)
        func cancelPending(id: String)
        func removeDelivered(id: String)
    }

    private let center: any Center

    init(center: any Center = SystemCenter()) {
        self.center = center
    }

    /// True when the player has already granted alerts (no prompt).
    func isAuthorized() async -> Bool {
        let status = await center.authorizationStatus()
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Current authorization status for sheet chrome (done / ask / denied).
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    /// System prompt — from the OUT OF LIVES row, or from a defeat that
    /// emptied the pool (see `offerAuthorizationAfterDefeat`).
    @discardableResult
    func requestAuthorization() async -> Bool {
        await center.requestAuthorization()
    }

    /// Defeat entry: when the run that just ended took the last life, wait
    /// a beat so the panel lands first, then ask once. No-ops unless the
    /// status is still undecided, so the prompt is never spent twice.
    /// `delay` is injectable so tests don't sit through the real beat.
    func offerAuthorizationAfterDefeat(
        lives: Int,
        duringTutorial: Bool,
        delay: TimeInterval = LivesRestockNotify.authorizationPromptDelay
    ) async {
        guard LivesRestockNotify.shouldOfferAuthorization(
            lives: lives,
            status: await authorizationStatus(),
            duringTutorial: duringTutorial
        ) else { return }
        try? await Task.sleep(for: .seconds(delay))
        // The one authorization prompt in the app — whether players take it
        // decides D-11 (is the restock notification worth keeping).
        let granted = await requestAuthorization()
        await MainActor.run {
            Analytics.design(granted ? "notif:restock:optin" : "notif:restock:deny")
        }
    }

    /// Background entry: if authorized and below cap, schedule exactly once
    /// at seconds-until-full; if full, cancel any pending.
    func syncOnBackground(secondsUntilFull: Int?) async {
        guard await isAuthorized() else {
            center.cancelPending(id: LivesRestockNotify.identifier)
            return
        }
        apply(LivesRestockNotify.plan(secondsUntilFull: secondsUntilFull))
    }

    /// Foreground entry: clear pending + delivered so no stale banner
    /// sits in Notification Center while they play.
    func syncOnActive() {
        center.cancelPending(id: LivesRestockNotify.identifier)
        center.removeDelivered(id: LivesRestockNotify.identifier)
    }

    /// Applies a pure plan to the center (testable without store/clock).
    func apply(_ plan: LivesRestockNotify.Plan) {
        switch plan {
        case .schedule(let seconds):
            center.schedule(
                id: LivesRestockNotify.identifier,
                afterSeconds: TimeInterval(seconds),
                title: LivesRestockNotify.title,
                body: LivesRestockNotify.body
            )
        case .cancel:
            center.cancelPending(id: LivesRestockNotify.identifier)
        }
    }

    // MARK: - System center

    /// Production UNUserNotificationCenter adapter.
    @MainActor
    final class SystemCenter: Center {
        func authorizationStatus() async -> UNAuthorizationStatus {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }

        func requestAuthorization() async -> Bool {
            do {
                return try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        }

        func schedule(id: String, afterSeconds: TimeInterval, title: String, body: String) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            // No badge — the app has no badge currency.
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, afterSeconds),
                repeats: false
            )
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            // Same id replaces any prior pending request — never stacks.
            UNUserNotificationCenter.current().add(request)
        }

        func cancelPending(id: String) {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [id])
        }

        func removeDelivered(id: String) {
            UNUserNotificationCenter.current()
                .removeDeliveredNotifications(withIdentifiers: [id])
        }
    }
}
