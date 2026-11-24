import AVFoundation
import UIKit

/// Plays Isle's synthesised sounds through a small pool of player nodes.
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private let ambientPlayer = AVAudioPlayerNode()
    private var nextPlayer = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var configured = false
    private(set) var ambientKind: String? = nil

    private func setUp() -> Bool {
        guard let format = format else { return false }
        if !configured {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            for _ in 0..<6 {
                let p = AVAudioPlayerNode()
                engine.attach(p)
                engine.connect(p, to: engine.mainMixerNode, format: format)
                players.append(p)
            }
            engine.attach(ambientPlayer)
            engine.connect(ambientPlayer, to: engine.mainMixerNode, format: format)
            configured = true
        }
        engine.mainMixerNode.outputVolume = Float(Feedback.volume)
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return true
    }

    private func buffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let format = format, !samples.isEmpty,
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress { channel.update(from: base, count: samples.count) }
        }
        return buf
    }

    func play(_ name: String) {
        guard setUp() else { return }
        let pack = Feedback.pack
        let key = pack + ":" + name
        var buf = cache[key]
        if buf == nil {
            buf = buffer(from: Synth.render(name, pack: pack))
            cache[key] = buf
        }
        guard let b = buf, !players.isEmpty else { return }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.stop()
        p.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
        p.play()
    }

    func startAmbient(_ kind: String) {
        stopAmbient()
        guard kind != "off", Feedback.soundOn, setUp() else { return }
        let key = "ambient:" + kind
        var buf = cache[key]
        if buf == nil {
            buf = buffer(from: Synth.ambient(kind))
            cache[key] = buf
        }
        guard let b = buf else { return }
        ambientPlayer.volume = 0.9
        ambientPlayer.scheduleBuffer(b, at: nil, options: [.loops], completionHandler: nil)
        ambientPlayer.play()
        ambientKind = kind
    }

    func stopAmbient() {
        ambientPlayer.stop()
        ambientKind = nil
    }

    func setVolume(_ v: Double) {
        if configured { engine.mainMixerNode.outputVolume = Float(v) }
    }

    func clearCache() { cache.removeAll() }
}

enum Haptic {
    case light, medium, soft, rigid, success, warning
}

enum IsleHaptics {
    static func play(_ h: Haptic) {
        switch h {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .soft: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

/// Every sound Isle makes, with the haptic it pairs with (spec: Sound and haptics).
enum Sfx {
    case tap, tick, undo, shell, chip(Int), lift, place(Int), hmm, whoosh, slide, chirp, sleepy
    case celebrate, bloom(Int), count(Int), knock, crack, hatch, bowl, pause, resume

    var name: String {
        switch self {
        case .tap: return "tap"
        case .tick: return "tick"
        case .undo: return "undo"
        case .shell: return "shell"
        case .chip(let i): return "chip\(max(0, i) % 10)"
        case .lift: return "lift"
        case .place(let d): return "place\(max(0, d) % 7)"
        case .hmm: return "hmm"
        case .whoosh: return "whoosh"
        case .slide: return "slide"
        case .chirp: return "chirp"
        case .sleepy: return "sleepy"
        case .celebrate: return "celebrate"
        case .bloom(let i): return "bloom\(max(0, i) % 10)"
        case .count(let i): return "count\(max(0, i) % 4)"
        case .knock: return "knock"
        case .crack: return "crack"
        case .hatch: return "hatch"
        case .bowl: return "bowl"
        case .pause: return "pause"
        case .resume: return "resume"
        }
    }

    var haptic: Haptic? {
        switch self {
        case .tap, .undo, .chip, .bloom: return .light
        case .tick, .celebrate, .hatch: return .success
        case .lift, .place: return .medium
        case .hmm: return .warning
        case .whoosh, .chirp, .bowl, .pause, .resume: return .soft
        case .knock, .crack: return .rigid
        case .shell, .sleepy, .slide, .count: return nil
        }
    }
}

enum Feedback {
    static let defaults = UserDefaults.standard

    static var soundOn: Bool {
        get { defaults.object(forKey: "isle.soundOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "isle.soundOn"); if !newValue { SoundEngine.shared.stopAmbient() } }
    }
    static var hapticsOn: Bool {
        get { defaults.object(forKey: "isle.hapticsOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "isle.hapticsOn") }
    }
    static var volume: Double {
        get { defaults.object(forKey: "isle.volume") as? Double ?? 0.7 }
        set { defaults.set(newValue, forKey: "isle.volume"); SoundEngine.shared.setVolume(newValue) }
    }
    static var pack: String {
        get { defaults.string(forKey: "isle.pack") ?? "wood" }
        set { defaults.set(newValue, forKey: "isle.pack") }
    }

    static func play(_ s: Sfx) {
        if soundOn { SoundEngine.shared.play(s.name) }
        if hapticsOn, let h = s.haptic { IsleHaptics.play(h) }
    }

    static func play(_ s: Sfx, after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { Feedback.play(s) }
    }
}
