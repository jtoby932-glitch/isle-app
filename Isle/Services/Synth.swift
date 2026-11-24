import Foundation

/// Offline synthesiser for Isle's sounds. Every melodic sound stays in one pentatonic scale
/// (C D E G A from C5), so overlapping sounds always harmonise. Mirrors the prototype's isle-sfx.js.
enum Synth {
    static let sampleRate: Double = 44100
    static let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51, 1567.98, 1760.0]

    enum Wave { case sine, triangle }

    // MARK: building blocks

    static func tone(_ b: inout [Float], f: Double, t0: Double, dur: Double, gain: Double,
                     attack: Double = 0.004, wave: Wave = .sine, to: Double? = nil, lowpass: Double? = nil) {
        let start = Int(t0 * sampleRate)
        let count = Int(dur * sampleRate)
        guard count > 0, gain > 0 else { return }
        let peak = gain
        let decayTime = max(0.001, dur - attack)
        let k = log(peak / 0.0001) / decayTime
        var phase = 0.0
        var lp: Double = 0
        let lpA: Double = lowpass.map { 1 - exp(-2 * Double.pi * $0 / sampleRate) } ?? 1
        for i in 0..<count {
            let idx = start + i
            if idx >= b.count { break }
            let t = Double(i) / sampleRate
            var freq = f
            if let to = to {
                let p = min(1, t / max(0.02, dur * 0.8))
                freq = f * pow(to / f, p)
            }
            phase += 2 * Double.pi * freq / sampleRate
            var v: Double
            switch wave {
            case .sine: v = sin(phase)
            case .triangle: v = 2 / Double.pi * asin(sin(phase))
            }
            if lowpass != nil {
                lp += lpA * (v - lp)
                v = lp
            }
            let env = t < attack ? peak * (t / attack) : peak * exp(-k * (t - attack))
            b[idx] += Float(v * env)
        }
    }

    static func noise(_ b: inout [Float], t0: Double, dur: Double, gain: Double, center: Double = 2000,
                      q: Double = 1.2, sweep: Double? = nil, attack: Double = 0.003) {
        let start = Int(t0 * sampleRate)
        let count = Int(dur * sampleRate)
        guard count > 0 else { return }
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var b0 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0
        let peak = gain
        let k = log(peak / 0.0001) / max(0.001, dur - attack)
        for i in 0..<count {
            let idx = start + i
            if idx >= b.count { break }
            let t = Double(i) / sampleRate
            if i % 64 == 0 {
                var fc = center
                if let s = sweep { fc = center * pow(s / center, t / dur) }
                let w0 = 2 * Double.pi * min(fc, sampleRate * 0.45) / sampleRate
                let alpha = sin(w0) / (2 * q)
                b0 = alpha; b2 = -alpha
                a0 = 1 + alpha; a1 = -2 * cos(w0); a2 = 1 - alpha
            }
            let x = Double.random(in: -1...1)
            let y = (b0 * x + b2 * x2 - a1 * y1 - a2 * y2) / a0
            x2 = x1; x1 = x; y2 = y1; y1 = y
            let env = t < attack ? peak * (t / attack) : peak * exp(-k * (t - attack))
            b[idx] += Float(y * env * 3)
        }
    }

    /// One "note" in the chosen pack. wood = marimba, glass = bell, soft = felt piano.
    static func note(_ b: inout [Float], f: Double, t0: Double, gain g: Double = 0.24, pack: String) {
        switch pack {
        case "glass":
            tone(&b, f: f, t0: t0, dur: 1.1, gain: g * 0.8)
            tone(&b, f: f * 2.76, t0: t0, dur: 0.45, gain: g * 0.18)
            tone(&b, f: f * 5.4, t0: t0, dur: 0.15, gain: g * 0.06)
        case "soft":
            tone(&b, f: f / 2, t0: t0, dur: 0.6, gain: g, attack: 0.012, wave: .triangle, lowpass: 1400)
        default:
            tone(&b, f: f, t0: t0, dur: 0.32, gain: g)
            tone(&b, f: f * 4, t0: t0, dur: 0.06, gain: g * 0.16)
            tone(&b, f: f * 10, t0: t0, dur: 0.015, gain: g * 0.05)
        }
    }

    static func p(_ i: Int) -> Double { scale[((i % scale.count) + scale.count) % scale.count] }

    // MARK: recipes

    static func length(of name: String) -> Double {
        switch base(name) {
        case "bowl": return 3.4
        case "celebrate", "hatch": return 1.6
        case "hmm", "whoosh", "sleepy", "slide": return 0.7
        default: return 1.2
        }
    }

    static func base(_ name: String) -> String { name.trimmingCharacters(in: .decimalDigits) }
    static func arg(_ name: String) -> Int { Int(name.filter { $0.isNumber }) ?? 0 }

    static func render(_ name: String, pack: String) -> [Float] {
        var b = [Float](repeating: 0, count: Int(length(of: name) * sampleRate))
        let a = arg(name)
        switch base(name) {
        case "tap":
            noise(&b, t0: 0, dur: 0.025, gain: 0.07, center: 2600)
            tone(&b, f: 1100, t0: 0, dur: 0.03, gain: 0.035, wave: .triangle)
        case "tick":
            note(&b, f: p(2), t0: 0, pack: pack)
            note(&b, f: p(4), t0: 0.075, pack: pack)
        case "undo":
            note(&b, f: p(4), t0: 0, gain: 0.15, pack: pack)
            note(&b, f: p(1), t0: 0.07, gain: 0.13, pack: pack)
        case "shell":
            tone(&b, f: p(7) * 2, t0: 0.14, dur: 0.22, gain: 0.05, wave: .triangle)
            tone(&b, f: p(9) * 2, t0: 0.19, dur: 0.3, gain: 0.04, wave: .triangle)
        case "chip":
            note(&b, f: p(a), t0: 0, gain: 0.11, pack: pack)
        case "place":
            let f = p(a % 7)
            note(&b, f: f, t0: 0, gain: 0.24, pack: pack)
            tone(&b, f: f / 2, t0: 0, dur: 0.22, gain: 0.07, wave: .triangle)
            noise(&b, t0: 0, dur: 0.05, gain: 0.05, center: 500)
        case "lift":
            tone(&b, f: 500, t0: 0, dur: 0.09, gain: 0.07, wave: .triangle, to: 760)
        case "hmm":
            tone(&b, f: 392, t0: 0, dur: 0.17, gain: 0.11, wave: .triangle, lowpass: 1100)
            tone(&b, f: 330, t0: 0.15, dur: 0.3, gain: 0.11, wave: .triangle, lowpass: 1100)
        case "whoosh":
            noise(&b, t0: 0, dur: 0.4, gain: 0.1, center: 700, q: 0.8, sweep: 2600, attack: 0.08)
        case "slide":
            noise(&b, t0: 0, dur: 0.22, gain: 0.06, center: 1800, q: 0.7, sweep: 900, attack: 0.03)
            note(&b, f: p(3), t0: 0.12, gain: 0.12, pack: pack)
        case "chirp":
            tone(&b, f: 1050, t0: 0, dur: 0.1, gain: 0.08, to: 1700)
            tone(&b, f: 1300, t0: 0.12, dur: 0.13, gain: 0.07, to: 2000)
        case "sleepy":
            tone(&b, f: 700, t0: 0, dur: 0.35, gain: 0.05, attack: 0.05, to: 420)
        case "celebrate":
            for (i, n) in [0, 2, 4, 5].enumerated() { note(&b, f: p(n), t0: Double(i) * 0.1, gain: 0.22, pack: pack) }
            note(&b, f: p(7), t0: 0.42, gain: 0.18, pack: pack)
            tone(&b, f: p(5), t0: 0.42, dur: 1.0, gain: 0.05, wave: .triangle)
            tone(&b, f: p(7) * 2, t0: 0.14, dur: 0.22, gain: 0.05, wave: .triangle)
            tone(&b, f: p(9) * 2, t0: 0.19, dur: 0.3, gain: 0.04, wave: .triangle)
        case "bloom":
            let f = p(a + 3)
            note(&b, f: f, t0: 0, gain: 0.17, pack: pack)
            tone(&b, f: f * 2, t0: 0.03, dur: 0.35, gain: 0.025, wave: .triangle)
        case "count":
            tone(&b, f: p(5 + a % 4) * 2, t0: 0, dur: 0.04, gain: 0.03, wave: .triangle)
        case "knock":
            tone(&b, f: 190, t0: 0, dur: 0.11, gain: 0.3, to: 95)
            noise(&b, t0: 0, dur: 0.04, gain: 0.1, center: 650)
        case "crack":
            noise(&b, t0: 0, dur: 0.1, gain: 0.16, center: 3200)
            noise(&b, t0: 0.04, dur: 0.07, gain: 0.12, center: 4800)
        case "hatch":
            noise(&b, t0: 0, dur: 0.22, gain: 0.16, center: 2600)
            for (i, n) in [0, 2, 4, 7].enumerated() { note(&b, f: p(n), t0: 0.12 + Double(i) * 0.075, gain: 0.2, pack: pack) }
            tone(&b, f: 1050, t0: 0.62, dur: 0.1, gain: 0.08, to: 1700)
            tone(&b, f: 1300, t0: 0.74, dur: 0.13, gain: 0.07, to: 2000)
        case "bowl":
            for (f, g) in [(262.0, 0.13), (528.0, 0.06), (786.0, 0.035), (1310.0, 0.015)] {
                tone(&b, f: f, t0: 0, dur: 3.2, gain: g, attack: 0.015)
            }
        case "pause":
            note(&b, f: p(3), t0: 0, gain: 0.12, pack: pack)
            note(&b, f: p(1), t0: 0.06, gain: 0.1, pack: pack)
        case "resume":
            note(&b, f: p(1), t0: 0, gain: 0.1, pack: pack)
            note(&b, f: p(3), t0: 0.06, gain: 0.12, pack: pack)
        default:
            break
        }
        // gentle master: a little gain and a soft clip so stacked notes never crackle
        for i in b.indices { b[i] = Float(tanh(Double(b[i]) * 1.4)) }
        return trimmed(b)
    }

    static func trimmed(_ b: [Float]) -> [Float] {
        var end = b.count
        while end > 1, abs(b[end - 1]) < 0.0002 { end -= 1 }
        return Array(b.prefix(min(b.count, end + 256)))
    }

    // MARK: ambient beds for Focus (12 s loops)

    static func ambient(_ kind: String) -> [Float] {
        let seconds = 12.0
        let n = Int(seconds * sampleRate)
        var b = [Float](repeating: 0, count: n)
        var lp = 0.0, lp2 = 0.0, brown = 0.0
        switch kind {
        case "rain":
            let aLow = 1 - exp(-2 * Double.pi * 400 / sampleRate)
            let aHigh = 1 - exp(-2 * Double.pi * 5200 / sampleRate)
            for i in 0..<n {
                let x = Double.random(in: -1...1)
                lp += aLow * (x - lp)
                let hp = x - lp
                lp2 += aHigh * (hp - lp2)
                b[i] = Float(lp2 * 0.22)
            }
            var t = 0.0
            while t < seconds - 0.1 {
                if Double.random(in: 0...1) < 0.6 {
                    tone(&b, f: Double.random(in: 2400...5000), t0: t, dur: 0.03, gain: 0.02)
                }
                t += 0.09
            }
        case "waves":
            let a = 1 - exp(-2 * Double.pi * 650 / sampleRate)
            for i in 0..<n {
                let x = Double.random(in: -1...1)
                brown = (brown + 0.02 * x) * 0.998
                lp += a * (brown - lp)
                let t = Double(i) / sampleRate
                let swell = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(2 * Double.pi * t / 6 - Double.pi / 2), 1.6)
                b[i] = Float(lp * 2.6 * swell)
            }
        case "cafe":
            let a = 1 - exp(-2 * Double.pi * 1100 / sampleRate)
            for i in 0..<n {
                let x = Double.random(in: -1...1)
                brown = (brown + 0.02 * x) * 0.997
                lp += a * (brown - lp)
                b[i] = Float(lp * 1.8)
            }
            var t = 0.3
            while t < seconds - 0.4 {
                if Double.random(in: 0...1) < 0.35 {
                    let f = Double.random(in: 2600...4400)
                    tone(&b, f: f, t0: t, dur: 0.18, gain: 0.018)
                    tone(&b, f: f * 1.5, t0: t + 0.01, dur: 0.12, gain: 0.009)
                }
                t += 0.7
            }
        default:
            return []
        }
        // crossfade the seam so the loop is invisible
        let fade = Int(0.25 * sampleRate)
        for i in 0..<fade {
            let w = Float(i) / Float(fade)
            b[i] = b[i] * w + b[n - fade + i] * (1 - w)
        }
        return Array(b.prefix(n - fade)).map { Float(tanh(Double($0))) }
    }
}
