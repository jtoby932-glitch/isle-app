import SwiftUI

struct SoundSettingsView: View {
    @State private var soundOn = Feedback.soundOn
    @State private var hapticsOn = Feedback.hapticsOn
    @State private var volume = Feedback.volume
    @State private var pack = Feedback.pack
    @State private var playing: String? = nil
    @State private var weekAt = -1
    @State private var ambient: String? = nil

    struct Item {
        let id: String
        let name: String
        let desc: String
        let haptic: String
        let sfx: Sfx?
    }

    private let groups: [(String, [Item])] = [
        ("Everyday", [
            Item(id: "tap", name: "Tap", desc: "Soft wooden click on any button", haptic: "Light", sfx: .tap),
            Item(id: "tick", name: "Tick off", desc: "Two rising notes", haptic: "Success", sfx: .tick),
            Item(id: "undo", name: "Undo", desc: "The same notes, falling", haptic: "Light", sfx: .undo),
            Item(id: "shell", name: "Shells earned", desc: "Tiny glassy sparkle", haptic: "None", sfx: .shell)
        ]),
        ("Planning", [
            Item(id: "chip", name: "Quick-add chip", desc: "Climbs the scale as Pip understands more", haptic: "Light", sfx: nil),
            Item(id: "lift", name: "Pick up a task", desc: "Little upward slide", haptic: "Medium", sfx: .lift),
            Item(id: "place", name: "Drop on a day", desc: "That day's note, with a soft thud", haptic: "Medium", sfx: .place(2)),
            Item(id: "hmm", name: "Heads-up", desc: "A gentle two-note hmm, never an alarm", haptic: "Warning", sfx: .hmm),
            Item(id: "whoosh", name: "Auto-plan", desc: "Breezy sweep before Pip places things", haptic: "Soft", sfx: .whoosh)
        ]),
        ("Pip", [
            Item(id: "chirp", name: "Pip chirp", desc: "Happy two-part tweet", haptic: "Soft", sfx: .chirp),
            Item(id: "sleepy", name: "Pip yawns", desc: "Slow falling sigh", haptic: "None", sfx: .sleepy),
            Item(id: "hatch", name: "Hatch", desc: "Crackle, rising sparkle, first chirp", haptic: "Success", sfx: .hatch)
        ]),
        ("Moments", [
            Item(id: "bloom", name: "Plants bloom", desc: "One note per plant as it grows", haptic: "Light", sfx: nil),
            Item(id: "celebrate", name: "Day grown", desc: "Short four-note fanfare", haptic: "Success", sfx: .celebrate)
        ]),
        ("Focus", [
            Item(id: "bowl", name: "Start and end", desc: "Singing bowl, rings for a few seconds", haptic: "Soft", sfx: .bowl),
            Item(id: "amb:rain", name: "Rain", desc: "Soft rain with drips", haptic: "None", sfx: nil),
            Item(id: "amb:waves", name: "Waves", desc: "Slow swell on the shore", haptic: "None", sfx: nil),
            Item(id: "amb:cafe", name: "Café", desc: "Low murmur, the odd cup clink", haptic: "None", sfx: nil)
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ToggleSwitch(label: "App sounds", isOn: $soundOn)
                    Divider().overlay(T.line)
                    HStack(spacing: 10) {
                        Text("Volume").font(.isle(.subheadline)).foregroundStyle(T.ink)
                        Slider(value: $volume, in: 0...1, onEditingChanged: { editing in
                            if !editing { Feedback.play(.tick) }
                        })
                        Text("\(Int(volume * 100))%").font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted).monospacedDigit().frame(width: 44)
                    }
                    .frame(minHeight: 52)
                    Divider().overlay(T.line)
                    ToggleSwitch(label: "Haptics", isOn: $hapticsOn)
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))

                SectionLabel(text: "Sound pack")
                HStack(spacing: 8) {
                    packButton("wood", "Wood", "marimba")
                    packButton("glass", "Glass", "little bells")
                    packButton("soft", "Soft", "felt piano")
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your week is a tune").font(.isle(.headline))
                            Text("Each day has its own note. Planning plays it.").font(.isle(.caption, .semibold)).opacity(0.75)
                        }
                        Spacer()
                        Button { playWeek() } label: {
                            Image(systemName: "play.fill").font(.system(size: 18, weight: .black)).foregroundStyle(T.primaryInk)
                                .frame(width: 48, height: 48).background(Circle().fill(T.primary))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("Play the week")
                    }
                    HStack(spacing: 5) {
                        ForEach(0..<7, id: \.self) { i in
                            Button {
                                Feedback.play(.place(i))
                                flashWeek(i)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(Day.shortNames[i]).font(.isle(.caption, .heavy))
                                    Text(["C", "D", "E", "G", "A", "C", "D"][i]).font(.isle(.caption2, .bold)).opacity(0.8)
                                }
                                .foregroundStyle(weekAt == i ? T.primaryInk : T.cream)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(RoundedRectangle(cornerRadius: 12).fill(weekAt == i ? T.primary : Color(hex: 0x3A3470)))
                                .offset(y: weekAt == i ? -6 : 0)
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: weekAt)
                        }
                    }
                }
                .foregroundStyle(T.cream)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x2B2848)))

                ForEach(0..<groups.count, id: \.self) { gi in
                    let g = groups[gi]
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: g.0)
                        VStack(spacing: 0) {
                            ForEach(0..<g.1.count, id: \.self) { ii in
                                row(g.1[ii])
                                if ii < g.1.count - 1 { Divider().overlay(T.line) }
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))
                    }
                }

                Text("Every sound uses one five-note scale, so sounds that overlap still harmonise. Doing things goes up in pitch, undoing goes down.")
                    .font(.isle(.footnote, .semibold)).foregroundStyle(T.ink)
                    .card(fill: T.primarySoft.opacity(0.5))
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("Sounds & haptics")
        .onChange(of: soundOn) { _, v in Feedback.soundOn = v; if v { Feedback.play(.tick) } }
        .onChange(of: hapticsOn) { _, v in Feedback.hapticsOn = v; if v { Haptics.play(.success) } }
        .onChange(of: volume) { _, v in Feedback.volume = v }
        .onDisappear { SoundEngine.shared.stopAmbient() }
    }

    private func packButton(_ id: String, _ name: String, _ desc: String) -> some View {
        let on = pack == id
        return Button {
            pack = id
            Feedback.pack = id
            Feedback.play(.tick)
        } label: {
            VStack(spacing: 2) {
                Text(name).font(.isle(.headline))
                Text(desc).font(.isle(.caption, .semibold)).opacity(0.8)
            }
            .foregroundStyle(T.ink)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(RoundedRectangle(cornerRadius: 16).fill(on ? T.primarySoft : T.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(_ item: Item) -> some View {
        let isAmbient = item.id.hasPrefix("amb:")
        let looping = isAmbient && ambient == String(item.id.dropFirst(4))
        let on = playing == item.id || looping
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                Text(item.desc).font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
            }
            Spacer()
            Tag(text: item.haptic == "None" ? "No haptic" : item.haptic)
            Button { play(item) } label: {
                Image(systemName: looping ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(T.ink)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 14).fill(on ? T.primary : T.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                    .scaleEffect(playing == item.id ? 1.1 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: playing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel((looping ? "Stop " : "Play ") + item.name)
        }
        .frame(minHeight: 56)
    }

    private func play(_ item: Item) {
        if item.id.hasPrefix("amb:") {
            let kind = String(item.id.dropFirst(4))
            if ambient == kind {
                SoundEngine.shared.stopAmbient()
                ambient = nil
            } else {
                SoundEngine.shared.startAmbient(kind)
                ambient = kind
            }
            return
        }
        if item.id == "chip" {
            for i in 0..<5 { Feedback.play(.chip(i), after: Double(i) * 0.06) }
        } else if item.id == "bloom" {
            for i in 0..<4 { Feedback.play(.bloom(i), after: Double(i) * 0.3) }
        } else if let s = item.sfx {
            Feedback.play(s)
        }
        playing = item.id
        let id = item.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if playing == id { playing = nil }
        }
    }

    private func flashWeek(_ i: Int) {
        weekAt = i
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if weekAt == i { weekAt = -1 }
        }
    }

    private func playWeek() {
        for d in 0..<7 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(d) * 210_000_000)
                Feedback.play(.place(d))
                weekAt = d
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7 * 210_000_000 + 200_000_000)
            Feedback.play(.celebrate)
            weekAt = -1
        }
    }
}
