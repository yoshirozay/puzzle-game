import SwiftUI
import UIKit
import UserNotifications

/// Shared OUT OF LIVES panel — house panel voice. Hearts, a live
/// "NEXT LIFE IN m:ss" countdown, and two placeholder recovery buttons
/// (ad / gold bars) that only flash COMING SOON. Nothing here grants lives.
///
/// When a life lands while the sheet is open, an optional gold primary
/// (`onLifeLandedPlay`) lets the player act immediately — launch the blocked
/// game or retry. Default nil keeps plain dismiss at every current call site.
/// The quiet notify row asks for notification authorization on demand; a
/// defeat that empties the pool also asks once, two seconds after the panel
/// lands (see `LivesRestockNotifier.offerAuthorizationAfterDefeat`). Neither
/// ever fires at launch. Once the status settles the row stops asking and
/// becomes state: ALERTS ON, or a deep link into Settings if it was denied.
struct OutOfLivesSheet: View {
    /// Pool rules line, derived so the copy can never drift from the
    /// constants the way the hardcoded "5 HEARTS · +1 EVERY 30 MIN" did.
    static var poolLine: String {
        let minutes = Int(PlayerStore.livesRefillPeriod / 60)
        let cadence = minutes % 60 == 0
            ? (minutes == 60 ? "HOUR" : "\(minutes / 60) HOURS")
            : "\(minutes) MIN"
        return "\(PlayerStore.livesCap) HEARTS · +1 EVERY \(cadence)"
    }

    let onDismiss: () -> Void
    /// Fired when the pool has refilled while open and the player taps the
    /// gold play CTA. Nil → no CTA (BACK still dismisses).
    var onLifeLandedPlay: (() -> Void)? = nil

    @Environment(PlayerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    /// Re-check authorization when the player returns from Settings.
    @Environment(\.scenePhase) private var scenePhase
    @State private var flash: String?
    @State private var entered = false
    /// Cached auth status for the wave-me-back row (refreshed on appear / tap).
    @State private var notifyStatus: UNAuthorizationStatus = .notDetermined
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        sheetBody
            // Instrumented on the sheet itself rather than on the six
            // sites that raise it, so a seventh caller cannot drift
            // out of sync. Denominator for D-5.
            .onAppear { Analytics.design("lives:empty:sheet") }
    }

    private var sheetBody: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let snap = store.livesSnapshot(now: context.date)
            let lifeLanded = snap.count > 0
            ZStack {
                P.ink.color.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                VStack(spacing: 14) {
                    Text("OUT OF LIVES")
                        .font(.custom("Futura-Bold", size: 22, relativeTo: .title2))
                        .tracking(3)
                        .foregroundStyle(P.blossom.color)

                    Text(Self.poolLine)
                        .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(P.cream.color.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    LivesHearts(
                        count: snap.count,
                        size: .panel,
                        secondsToNext: lifeLanded ? nil : snap.secondsToNext,
                        stackCountdown: false
                    )
                    .padding(.top, 2)

                    if lifeLanded {
                        Text("A LIFE JUST LANDED")
                            .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.torch.color)
                    }

                    if let flash {
                        Text(flash)
                            .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.coral.color)
                            .transition(.opacity)
                    }

                    VStack(spacing: 10) {
                        if lifeLanded, let play = onLifeLandedPlay {
                            Button {
                                play()
                            } label: {
                                Text("PLAY")
                                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                                    .tracking(2.5)
                                    .foregroundStyle(P.ink.color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Capsule().fill(Color(red: 0.910, green: 0.702, blue: 0.235)))
                            }
                            .buttonStyle(SoftPressStyle())
                        }

                        Button {
                            // The refill is INTENTIONAL (Carson, 2026-08-01) —
                            // a real feature, not a leftover. Don't remove it.
                            //
                            // What that means for the number: this tap reads as
                            // "I want my lives back now", not "I would watch an
                            // ad for them", because the reward lands without an
                            // ad ever playing. Still the strongest refill-demand
                            // signal we have, and the right denominator when an
                            // actual rewarded ad ships. See ANALYTICS_PLAN §2.2.
                            Analytics.design("lives:empty:watchad")
                            store.refillLivesToCap()
                            softHaptic.impactOccurred()
                            flashComingSoon("LIVES REFILLED")
                        } label: {
                            Text("WATCH AN AD  ·  REFILL")
                                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.ink.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(P.torch.color))
                        }
                        .buttonStyle(SoftPressStyle())

                        Button {
                            Analytics.design("lives:empty:goldbar")
                            flashComingSoon("COMING SOON")
                        } label: {
                            Text("BUY LIVES · SOON")
                                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.ink.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color(red: 0.910, green: 0.702, blue: 0.235).opacity(lifeLanded ? 0.55 : 1)))
                        }
                        .buttonStyle(SoftPressStyle())

                        // Quiet restock-notify ask — the only authorization
                        // prompt in the app. Below the COMING-SOON placeholders,
                        // above BACK.
                        notifyAffordance

                        Button {
                            Analytics.design("lives:empty:dismiss")
                            onDismiss()
                        } label: {
                            Text("BACK")
                                .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.blossom.color)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Capsule().stroke(P.blossom.color.opacity(0.7), lineWidth: 1.5))
                        }
                        .buttonStyle(SoftPressStyle())
                        .padding(.top, 2)
                    }
                    .padding(.top, 4)
                }
                .padding(28)
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(P.woodDark.color)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.ink.color, lineWidth: 2))
                )
                .scaleEffect(reduceMotion ? 1 : (entered ? 1 : 0.92))
                .opacity(entered ? 1 : 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            softHaptic.prepare()
            softHaptic.impactOccurred(intensity: 0.7)
            if reduceMotion {
                entered = true
            } else {
                withAnimation(.spring(duration: 0.4, bounce: 0.28)) { entered = true }
            }
            Task { await refreshNotifyStatus() }
        }
        // Coming back from Settings lands here as an active transition —
        // re-read authorization so the row chrome flips without a re-tap.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshNotifyStatus() }
            }
        }
    }

    /// Ask / done / denied chrome for the restock local notification.
    @ViewBuilder
    private var notifyAffordance: some View {
        let authorized = notifyStatus == .authorized
            || notifyStatus == .provisional
            || notifyStatus == .ephemeral
        let denied = notifyStatus == .denied
        Button {
            Task { await handleNotifyTap() }
        } label: {
            Text(authorized ? "ALERTS ON" : "NOTIFY WHEN LIVES FULL")
                .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(
                    authorized
                        ? P.cream.color.opacity(0.55)
                        : P.blossom.color.opacity(0.85)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(authorized)
        .accessibilityLabel(
            authorized
                ? "Restock alerts enabled"
                : denied
                    ? "Restock alerts denied — enable in Settings"
                    : "Wave me back when lives are full"
        )
        .accessibilityHint(
            authorized
                ? "Notifications are already on"
                : denied
                    ? "Open Settings to enable notifications"
                    : "Ask for a notification when all five lives return"
        )
    }

    private func handleNotifyTap() async {
        let status = await LivesRestockNotifier.shared.authorizationStatus()
        if status == .authorized || status == .provisional || status == .ephemeral {
            await refreshNotifyStatus()
            return
        }
        if status == .denied {
            // The a11y hint promises Settings — take them there. The flash
            // covers the (theoretical) failure to open.
            flashMessage("ENABLE IN SETTINGS")
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                openURL(url)
            }
            return
        }
        // notDetermined (or rare .ephemeral edge) — the only system prompt.
        let granted = await LivesRestockNotifier.shared.requestAuthorization()
        await refreshNotifyStatus()
        if granted {
            flashMessage("WE'LL WAVE YOU BACK")
        } else {
            flashMessage("ENABLE IN SETTINGS")
        }
    }

    @MainActor
    private func refreshNotifyStatus() async {
        notifyStatus = await LivesRestockNotifier.shared.authorizationStatus()
    }

    private func flashComingSoon(_ label: String) {
        flashMessage("\(label) — COMING SOON")
    }

    private func flashMessage(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            flash = text
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.2)) { flash = nil }
        }
    }
}

#Preview {
    OutOfLivesSheet(onDismiss: {})
        .environment(PlayerStore(inMemory: true))
}
