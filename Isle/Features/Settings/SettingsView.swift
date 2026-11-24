import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsRows: [AppSettings]
    @Query private var isles: [IsleState]
    @Query private var tasks: [TaskItem]
    @Query(sort: \Habit.order) private var habits: [Habit]

    @State private var confirmReset = false
    @State private var showSounds = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let s = settingsRows.first, let isle = isles.first {
                    SettingsContent(settings: s, isle: isle, confirmReset: $confirmReset, showSounds: $showSounds)
                }
            }
            .screenBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if let s = settingsRows.first {
                            IsleNotifications.reschedule(tasks: tasks, habits: habits, settings: s, pipName: isles.first?.pipName ?? "Pip")
                        }
                        try? context.save()
                        dismiss()
                    }
                    .font(.isle(.headline))
                }
            }
            .navigationDestination(isPresented: $showSounds) { SoundSettingsView() }
            .confirmationDialog("Erase everything in Isle?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase all tasks, habits and Pip", role: .destructive) {
                    Store(context: context).resetEverything()
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

private struct SettingsContent: View {
    @Bindable var settings: AppSettings
    @Bindable var isle: IsleState
    @Binding var confirmReset: Bool
    @Binding var showSounds: Bool
    private var calendar: CalendarService { CalendarService.shared }
    @State private var notifDenied = false
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 16) {
            Button {
                app.showSettings = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(380))
                    SideSwitcher.shared.switchTo(.prime)
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: 0x05070B))
                        PrimeMark().fill(Color(hex: 0x3D6BFF)).frame(width: 16, height: 16)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Switch to PRIME").font(.isle(.headline)).foregroundStyle(T.ink)
                        Text("Your gym app, in here too").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 14, weight: .heavy)).foregroundStyle(T.muted)
                }
                .card(padding: 12)
            }
            .buttonStyle(PressStyle())

            section("Pip") {
                HStack(spacing: 10) {
                    PipView(mood: .happy, size: 56, colorIndex: isle.bodyColorIndex, outfit: isle.outfit)
                    TextField("Name", text: $isle.pipName)
                        .font(.isle(.headline))
                        .padding(.horizontal, 10).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(T.surface2))
                }
                .padding(.vertical, 6)
            }

            section("Planning") {
                stepperRow("Hours you can plan, weekdays", value: $settings.capacityWeekday)
                divider
                stepperRow("Hours you can plan, weekends", value: $settings.capacityWeekend)
                divider
                ToggleSwitch(label: "Ask about unfinished tasks", isOn: $settings.rolloverAsk)
                divider
                ToggleSwitch(label: "Morning battery check-in", isOn: $settings.checkinOn)
                divider
                HStack {
                    Text("Sunday planning reminder").font(.isle(.subheadline)).foregroundStyle(T.ink)
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: { Day.dateAt(Day.today, minutes: settings.sundayPlanMinutes) },
                        set: { d in
                            let c = Day.calendar.dateComponents([.hour, .minute], from: d)
                            settings.sundayPlanMinutes = (c.hour ?? 19) * 60 + (c.minute ?? 0)
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
                .frame(minHeight: 48)
            }

            section("Look & feel") {
                HStack {
                    Text("Theme").font(.isle(.subheadline)).foregroundStyle(T.ink)
                    Spacer()
                    SegmentedPicker(options: [("light", "Light"), ("dark", "Dark"), ("auto", "Auto")], selection: $settings.themeRaw)
                        .frame(width: 200)
                }
                .frame(minHeight: 50)
                divider
                Button { Feedback.play(.tap); showSounds = true } label: {
                    HStack {
                        Text("Sounds & haptics").font(.isle(.subheadline)).foregroundStyle(T.ink)
                        Spacer()
                        Text(Feedback.soundOn ? Feedback.pack.capitalized : "Off").font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .black)).foregroundStyle(T.ink)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            section("Notifications") {
                ToggleSwitch(label: "Notifications", isOn: Binding(
                    get: { settings.notificationsOn },
                    set: { on in
                        if on {
                            Task { @MainActor in
                                let ok = await IsleNotifications.requestAuthorization()
                                settings.notificationsOn = ok
                                notifDenied = !ok
                            }
                        } else {
                            settings.notificationsOn = false
                        }
                    }
                ))
                if notifDenied {
                    Text("Notifications are off for Isle in iPhone Settings.").font(.isle(.caption, .semibold)).foregroundStyle(T.warnText)
                }
                if settings.notificationsOn {
                    divider
                    HStack {
                        Text("Style").font(.isle(.subheadline)).foregroundStyle(T.ink)
                        Spacer()
                        SegmentedPicker(options: [("gentle", "Gentle"), ("normal", "Normal"), ("essentials", "Essentials")], selection: $settings.notifStyle)
                            .frame(width: 250)
                    }
                    .frame(minHeight: 50)
                    Text(styleText).font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                }
            }

            section("Calendar") {
                if calendar.authorized {
                    ToggleSwitch(label: "Show calendar events", isOn: Binding(
                        get: { settings.calendarOn },
                        set: { settings.calendarOn = $0; calendar.invalidate() }
                    ))
                    Text("Read only. Events show beside your tasks and count towards each day's load.")
                        .font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                } else {
                    Button {
                        Task { @MainActor in
                            let ok = await calendar.requestAccess()
                            settings.calendarOn = ok
                            Feedback.play(ok ? .tick : .hmm)
                        }
                    } label: {
                        HStack {
                            Text("Connect calendar").font(.isle(.subheadline)).foregroundStyle(T.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .black)).foregroundStyle(T.ink)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Erase everything") { confirmReset = true }
                .font(.isle(.subheadline)).foregroundStyle(T.danger)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.danger, lineWidth: 2))

            Text("Isle 1.0 · made for one person, so no accounts, no ads and nothing for sale.")
                .font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }

    private var styleText: String {
        switch settings.notifStyle {
        case "gentle": return "Up to 3 a day, only things with a time. Never during 22:00–07:00."
        case "normal": return "Timed things plus a nudge for habits with a time."
        default: return "Only tasks with a start time, Sunday planning and Focus."
        }
    }

    private var divider: some View { Divider().overlay(T.line) }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: title)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(T.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label).font(.isle(.subheadline)).foregroundStyle(T.ink)
            Spacer()
            Text(Fmt.duration(value.wrappedValue)).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink).monospacedDigit()
            Stepper("", value: value, in: 60...720, step: 30).labelsHidden()
        }
        .frame(minHeight: 50)
    }
}
