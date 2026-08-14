import SwiftUI
import AVFoundation

// MARK: - Player vault

/// Owns the picker's AVPlayers so cards and the launch-expansion overlay can
/// share one instance per slot (no restart mid-transition). Policy per
/// PICKER_SPEC §8: at most focused ± 1 alive, only the focused player plays,
/// everything torn down on close. Low Power Mode / serious thermals disable
/// player creation entirely — posters carry the screen. Keyed by PickerSlot
/// so the lounge card (position 0) plays its pan clip through the same
/// window as its game neighbors.
@MainActor
@Observable
final class PreviewPlayers {

    private struct Entry {
        let player: AVQueuePlayer
        let looper: AVPlayerLooper
    }

    private var entries: [PickerSlot: Entry] = [:]

    var disabled: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
            || ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }

    /// Read-only lookup for view bodies — never creates (creation happens
    /// in focus(), off the render path).
    func existing(for slot: PickerSlot) -> AVPlayer? {
        entries[slot]?.player
    }

    /// Lazily creates (or returns) the looping muted player for a slot.
    func player(for slot: PickerSlot) -> AVPlayer? {
        if disabled { return nil }
        // The lounge and banner cards show designed crests, not clips —
        // never spend a decoder on them.
        if slot == .lounge || slot == .leaderboards { return nil }
        if let entry = entries[slot] { return entry.player }
        guard let url = slot.previewClipURL else { return nil }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        let looper = AVPlayerLooper(player: player, templateItem: item)
        entries[slot] = Entry(player: player, looper: looper)
        return player
    }

    /// Enforce the focused ± 1 window: play the focused slot, hold neighbors
    /// paused (warm, under their posters), tear down the rest.
    func focus(_ slot: PickerSlot?) {
        guard let slot, let index = PickerSlot.all.firstIndex(of: slot) else {
            pauseAll()
            return
        }
        for (owner, entry) in entries {
            guard let ownerIndex = PickerSlot.all.firstIndex(of: owner) else { continue }
            if abs(ownerIndex - index) > 1 {
                entry.player.pause()
                entries[owner] = nil
            } else if owner == slot {
                entry.player.play()
            } else {
                entry.player.pause()
            }
        }
        // Warm the window: create focused first, then neighbors.
        _ = player(for: slot)
        entries[slot]?.player.play()
        for offset in [-1, 1] {
            let n = index + offset
            if PickerSlot.all.indices.contains(n) {
                _ = player(for: PickerSlot.all[n])
            }
        }
    }

    func pauseAll() {
        for entry in entries.values { entry.player.pause() }
    }

    func teardownAll() {
        for entry in entries.values {
            entry.player.pause()
            entry.player.removeAllItems()
        }
        entries.removeAll()
    }
}

// MARK: - Preview assets

extension TikiGame {
    /// Bundle-resource stem shared by the clip and its poster. The encodes
    /// in Previews/ are pre-cropped below the recorded status bar, so the
    /// in-app crop offset is zero and posters are pixel-aligned first frames.
    var previewClipKey: String {
        switch self {
        case .tikiStacks: return "stacks"
        case .luau: return "luau"
        case .zombie: return "zombie"
        case .cabanaCipher: return "cipher"
        case .blueprints: return "blueprints"
        case .navigator: return "navigator"   // media lands in Stage 7; poster underlays until then
        }
    }

    /// Width / height of the encoded previews (930x1908).
    static let previewAspect: CGFloat = 930.0 / 1908.0
}

extension PickerSlot {
    /// The lounge shares the games' preview grammar — same encode envelope,
    /// same poster crossfade — under its own bundle stem.
    var previewClipKey: String {
        switch self {
        case .lounge: return "lounge"
        // No clip ships under this stem — the banner card draws
        // LeaderboardBannerCrest instead of a video window.
        case .leaderboards: return "leaderboards"
        case .game(let g): return g.previewClipKey
        }
    }

    var previewClipURL: URL? {
        Bundle.main.url(forResource: "preview-\(previewClipKey)", withExtension: "mp4")
    }

    var previewPoster: Image? {
        // UIImage(named:) uses the system cache — the decode happens once,
        // not on every card re-render.
        guard let ui = UIImage(named: "poster-\(previewClipKey).png") else { return nil }
        return Image(uiImage: ui)
    }
}

// MARK: - Preview view

/// One card's media window: the poster renders from the first frame through
/// identical geometry as the video, so the poster→live crossfade never
/// jumps. Top-aligned fill — the window keeps each game's HUD and crops
/// only bottom scenery.
struct GamePreviewView: View {
    let slot: PickerSlot
    /// nil → poster only (Reduce Motion, Low Power, or beyond focused ± 1).
    let player: AVPlayer?
    /// Only the focused card shows live footage; neighbors hold posters.
    let playing: Bool
    /// .top keeps each game's HUD and crops only bottom scenery. The lounge
    /// passes .bottom — its scene is bottom-weighted (sea band up top), so
    /// the window spends its crop on sky instead of the room.
    var contentAlignment: Alignment = .top

    @State private var videoReady = false

    var body: some View {
        let aspect = TikiGame.previewAspect
        GeometryReader { geo in
            let scaledH = geo.size.width / aspect
            ZStack(alignment: contentAlignment) {
                P.woodDark.color
                if let poster = slot.previewPoster {
                    poster
                        .resizable()
                        .frame(width: geo.size.width, height: scaledH)
                }
                if let player {
                    PlayerLayerHost(player: player) {
                        videoReady = true
                    }
                    .frame(width: geo.size.width, height: scaledH)
                    .opacity(videoReady && playing ? 1 : 0)
                    .animation(.easeIn(duration: 0.20), value: videoReady && playing)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: contentAlignment)
            .clipped()
        }
        .onChange(of: player == nil) { _, isNil in
            // A torn-down player (beyond focused ± 1) must re-crossfade on
            // revisit, not hard-cut with a stale ready flag.
            if isNil { videoReady = false }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Layer host

/// AVPlayerLayer host; the vault owns the player. `onReady` fires when the
/// layer has a frame, so the poster can hand off without a black flash.
struct PlayerLayerHost: UIViewRepresentable {
    let player: AVPlayer
    var onReady: (@MainActor () -> Void)? = nil

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.observe(view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
            context.coordinator.observe(uiView.playerLayer)
        }
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: Coordinator) {
        uiView.playerLayer.player = nil
        coordinator.cancel()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady)
    }

    @MainActor
    final class Coordinator {
        private let onReady: (@MainActor () -> Void)?
        private var observation: NSKeyValueObservation?

        init(onReady: (@MainActor () -> Void)?) {
            self.onReady = onReady
        }

        func observe(_ layer: AVPlayerLayer) {
            observation = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { layer, _ in
                guard layer.isReadyForDisplay else { return }
                Task { @MainActor [weak self] in
                    self?.onReady?()
                }
            }
        }

        func cancel() {
            observation?.invalidate()
            observation = nil
        }
    }

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
