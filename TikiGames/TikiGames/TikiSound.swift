import AVFoundation
import Observation

/// Synthesized lounge SFX + ambient loop — no audio assets, everything
/// rendered as PCM on the fly. One sound grammar for all five games:
/// tick (routine), pop (small win), clear ladder (payoffs climb a marimba
/// pentatonic with combo intensity), soft thud (mistake), win/gameOver
/// stings, and a big fanfare for THE ZOMBIE-class moments.
///
/// Uses the `.ambient` session category: respects the silent switch and
/// mixes with whatever the player is already listening to. The master
/// toggle persists in UserDefaults and silences SFX and the ambient bed.
///
/// The ambient bed is currently disabled — see `ambientBedEnabled`.
///
/// MainActor-isolated for Swift 6 strict concurrency; the two slow jobs
/// (session activation, ambient render) run off-main in detached tasks and
/// hand their results back explicitly.
@MainActor
@Observable
final class TikiSound {

    static let shared = TikiSound()
    private static let defaultsKey = "tikiSoundOn"
    private nonisolated static let sampleRate: Double = 44_100

    /// The ambient bed is OFF until audio gets a proper pass. The loop it
    /// plays is placeholder-grade — a 12-second procedural kalimba ostinato
    /// that repeats forever — and shipping music that thin is worse than
    /// shipping none. SFX are unaffected: they are gameplay feedback, not
    /// ambience, and they stay on.
    ///
    /// Flip this back to `true` to restore it; `renderAmbientLoop()` and the
    /// whole bed path below are intentionally left intact so re-enabling is
    /// a one-line change.
    private static let ambientBedEnabled = false

    /// Master switch, persisted. Flip via setEnabled.
    private(set) var enabled: Bool

    private let engine = AVAudioEngine()
    private let sfx = AVAudioPlayerNode()
    private let bed = AVAudioPlayerNode()
    private var started = false
    private var warming = false
    private var bedPlaying = false

    private init() {
        enabled = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: Self.defaultsKey)
        if on {
            startAmbientBed()
        } else {
            bed.stop()
            bedPlaying = false
        }
    }

    /// Session activation takes ~100-300ms — run it off-main at launch
    /// instead of stuttering the first placement. AVAudioSession is
    /// thread-safe; the engine wiring afterwards happens back on main.
    func warmUp() {
        guard !started, !warming else { return }
        warming = true
        Task.detached(priority: .userInitiated) {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            await TikiSound.shared.startEngine()
        }
    }

    private func startEngine() {
        warming = false
        guard !started else { return }
        do {
            let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
            engine.attach(sfx)
            engine.attach(bed)
            engine.connect(sfx, to: engine.mainMixerNode, format: format)
            engine.connect(bed, to: engine.mainMixerNode, format: format)
            try engine.start()
            sfx.play()
            started = true
            startAmbientBed()
        } catch {
            started = false
        }
    }

    // MARK: - Game events

    /// Routine acknowledgement: a tiny woodblock tick, pitch-randomized.
    func tick() {
        play(Self.pluck(frequency: 880 * .random(in: 0.97...1.03), duration: 0.045, volume: 0.18, brightness: 0.15))
    }

    /// Picker rail settle: the tick at a fixed pentatonic step, so paging
    /// through the six signs plays a six-note ladder (step 0-5).
    func railTick(step: Int) {
        let rates: [Double] = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0]
        let rate = rates[max(0, min(step, rates.count - 1))]
        play(Self.pluck(frequency: 880 * rate, duration: 0.045, volume: 0.18, brightness: 0.15))
    }

    /// Soft wood knock (card press, first-run nudge) — lower and rounder
    /// than a mistake thud.
    func knock() {
        play(Self.thud(frequency: 196 * .random(in: 0.97...1.03), duration: 0.09, volume: 0.26))
    }

    /// Small win (placement, fill, letter lock): warm marimba pop.
    func pop() {
        play(Self.pluck(frequency: 523.25 * .random(in: 0.985...1.015), duration: 0.09, volume: 0.4))
    }

    /// Payoff ladder: intensity 1+ climbs a C-major pentatonic, so streaks,
    /// cascades, and merge tiers are audible eyes-closed. Big intensities
    /// land a two-note chord.
    func clear(intensity: Int) {
        let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5, 1568.0, 1760.0]
        let step = max(0, min(intensity - 1, scale.count - 1))
        let f = scale[step] * .random(in: 0.99...1.01)
        if intensity >= 3 {
            play(Self.chord(frequencies: [f, f * 1.5], duration: 0.16, volume: 0.42))
        } else {
            play(Self.pluck(frequency: f, duration: 0.12, volume: 0.42))
        }
    }

    /// Soft low thud — deliberately quieter and shorter than success.
    func mistake() {
        play(Self.thud(frequency: 130 * .random(in: 0.96...1.04), duration: 0.16, volume: 0.32))
    }

    /// Rising pentatonic arpeggio for completions.
    func win() {
        play(Self.arpeggio(frequencies: [523.25, 659.25, 783.99, 1046.5], noteDuration: 0.1, volume: 0.45))
    }

    /// Two gentle descending notes. An ending, not a punishment.
    func gameOver() {
        play(Self.arpeggio(frequencies: [392.0, 261.63], noteDuration: 0.22, volume: 0.38))
    }

    /// The house fanfare: low root, then a five-note climb. THE ZOMBIE,
    /// CATACLYSM, and clean sweeps deserve the full band.
    func fanfare() {
        play(Self.chord(frequencies: [130.81, 196.0], duration: 0.35, volume: 0.4))
        play(Self.arpeggio(frequencies: [523.25, 587.33, 659.25, 783.99, 1046.5], noteDuration: 0.11, volume: 0.5))
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard enabled else { return }
        guard started else { warmUp(); return }
        sfx.scheduleBuffer(buffer, at: nil, options: [])
    }

    // MARK: - Ambient bed

    /// Unique-ownership handoff of a freshly rendered buffer from the render
    /// task back to the main actor (never touched again off-main).
    private struct BufferHandoff: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
    }

    /// A sparse 12-second kalimba ostinato over filtered surf noise, looped
    /// quietly under everything. Renders once, off the main thread.
    private func startAmbientBed() {
        guard Self.ambientBedEnabled else { return }
        guard enabled, started, !bedPlaying else { return }
        bedPlaying = true
        Task.detached(priority: .utility) {
            let handoff = BufferHandoff(buffer: Self.renderAmbientLoop())
            await TikiSound.shared.playAmbient(handoff)
        }
    }

    private func playAmbient(_ handoff: BufferHandoff) {
        guard enabled, started else {
            bedPlaying = false
            return
        }
        bed.scheduleBuffer(handoff.buffer, at: nil, options: [.loops])
        bed.volume = 0.35
        bed.play()
    }

    private nonisolated static func renderAmbientLoop() -> AVAudioPCMBuffer {
        let duration = 12.0
        // Kalimba notes on a lazy pattern: C4 E4 G4 A4 world, one note per
        // ~1.5s with gaps, plus a slow surf swell (LCG noise, no Foundation
        // randomness in the render loop for speed).
        let notes: [(start: Double, freq: Double)] = [
            (0.0, 261.63), (1.5, 329.63), (3.0, 392.0), (4.6, 440.0),
            (6.0, 392.0), (7.5, 329.63), (9.0, 293.66), (10.4, 261.63),
        ]
        var noise: UInt64 = 0x9E3779B97F4A7C15
        func nextNoise() -> Double {
            noise = noise &* 6364136223846793005 &+ 1442695040888963407
            return Double(Int64(bitPattern: noise >> 11)) / Double(Int64.max)
        }
        var low = 0.0
        return render(duration: duration) { t, progress in
            var sample = 0.0
            for note in notes {
                let dt = t - note.start
                guard dt >= 0, dt < 1.4 else { continue }
                let env = exp(-3.2 * dt)
                sample += 0.16 * env * (sin(2 * .pi * note.freq * dt) + 0.25 * sin(6 * .pi * note.freq * dt))
            }
            // Surf: one-pole low-passed noise swelling twice per loop.
            low += 0.02 * (nextNoise() - low)
            let swell = 0.5 + 0.5 * sin(2 * .pi * (progress * 2 - 0.25))
            sample += low * 0.55 * swell
            return Float(sample)
        }
    }

    // MARK: - Synthesis

    /// Marimba-ish pluck: fundamental + soft 2nd/4th partials, exponential
    /// decay. `brightness` raises the partial mix for clickier ticks.
    private nonisolated static func pluck(frequency: Double, duration: Double, volume: Float, brightness: Double = 0.3) -> AVAudioPCMBuffer {
        render(duration: duration) { t, progress in
            let envelope = exp(-5.5 * progress)
            let fundamental = sin(2 * .pi * frequency * t)
            let second = brightness * sin(4 * .pi * frequency * t)
            let fourth = brightness * 0.4 * sin(8 * .pi * frequency * t)
            return Float((fundamental + second + fourth) * envelope) * volume
        }
    }

    private nonisolated static func thud(frequency: Double, duration: Double, volume: Float) -> AVAudioPCMBuffer {
        render(duration: duration) { t, progress in
            let envelope = exp(-7.0 * progress)
            let body = sin(2 * .pi * frequency * t) + 0.2 * sin(.pi * frequency * t)
            return Float(body * envelope) * volume
        }
    }

    private nonisolated static func chord(frequencies: [Double], duration: Double, volume: Float) -> AVAudioPCMBuffer {
        render(duration: duration) { t, progress in
            let envelope = exp(-4.5 * progress)
            let mix = frequencies.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) } / Double(frequencies.count)
            return Float(mix * envelope) * volume
        }
    }

    private nonisolated static func arpeggio(frequencies: [Double], noteDuration: Double, volume: Float) -> AVAudioPCMBuffer {
        let total = noteDuration * Double(frequencies.count)
        return render(duration: total) { t, _ in
            let index = min(Int(t / noteDuration), frequencies.count - 1)
            let localT = t - Double(index) * noteDuration
            let envelope = exp(-4.0 * (localT / noteDuration))
            return Float(sin(2 * .pi * frequencies[index] * localT) * envelope) * volume
        }
    }

    private nonisolated static func render(duration: Double, sample: (Double, Double) -> Float) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            data[frame] = sample(t, t / duration)
        }
        return buffer
    }
}
