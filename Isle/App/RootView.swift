import SwiftUI
import SwiftData
import UIKit

struct IsleRootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Query private var settingsRows: [AppSettings]
    @Query private var isleRows: [IsleState]
    @Query private var tasks: [TaskItem]
    @Query private var habits: [Habit]

    var body: some View {
        let settings = settingsRows.first
        Group {
            if settings?.onboarded == true {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(scheme(settings?.themeRaw ?? "auto"))
        .onAppear {
            // Coming back from PRIME (always dark), make sure Auto follows the system again.
            if scheme(settings?.themeRaw ?? "auto") == nil { Self.followSystemStyle() }
        }
        .tint(T.ink)
        .onAppear {
            let store = Store(context: context)
            _ = store.settings()
            _ = store.isle()
            store.save()
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                reschedule()
            } else if newPhase == .active {
                CalendarService.shared.refreshStatus()
                CalendarService.shared.invalidate()
            }
        }
    }

    static func followSystemStyle() {
        Task { @MainActor in
            for scene in UIApplication.shared.connectedScenes {
                (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = .unspecified }
            }
        }
    }

    private func scheme(_ raw: String) -> ColorScheme? {
        switch raw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func reschedule() {
        guard let s = settingsRows.first else { return }
        IsleNotifications.reschedule(tasks: tasks, habits: habits, settings: s, pipName: isleRows.first?.pipName ?? "Pip")
    }
}

struct MainView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack(alignment: .bottom) {
            Group {
                switch app.tab {
                case .today: TodayView()
                case .week: WeekView()
                case .habits: HabitsView()
                case .isle: IsleView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                if let toast = app.toast {
                    IsleToastView(toast: toast) { app.runUndo() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                IsleTabBar()
            }
        }
        .screenBackground()
        .sheet(isPresented: $app.showQuickAdd) { QuickAddView().environment(app) }
        .sheet(item: $app.editingTask) { task in EditTaskView(task: task).environment(app) }
        .sheet(item: $app.openHabit) { habit in HabitDetailView(habit: habit).environment(app) }
        .sheet(isPresented: $app.showCheckin) { CheckinView().environment(app) }
        .sheet(isPresented: $app.showDayComplete) { DayCompleteView().environment(app) }
        .sheet(isPresented: $app.showSunday) { SundayPlanView().environment(app) }
        .sheet(isPresented: $app.showSearch) { SearchView().environment(app) }
        .sheet(isPresented: $app.showSettings) { SettingsView().environment(app) }
        .sheet(isPresented: $app.showShop) { ShopView().environment(app) }
        .fullScreenCover(isPresented: $app.showFocus) { FocusView(task: app.focusTask).environment(app) }
    }
}

struct IsleTabBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.today, "Today", "sun.max")
            item(.week, "Week", "calendar")
            Button {
                Feedback.play(.lift)
                app.showQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(T.primaryInk)
                    .frame(width: 58, height: 58)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 19, style: .continuous).fill(T.outline).offset(y: 3)
                            RoundedRectangle(cornerRadius: 19, style: .continuous).fill(T.primary)
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(T.outline, lineWidth: 2.5))
            }
            .buttonStyle(PressStyle())
            .offset(y: -16)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Quick add")
            item(.habits, "Habits", "leaf")
            item(.isle, "Isle", "water.waves")
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .frame(height: 64, alignment: .top)
        .background(
            T.surface
                .overlay(alignment: .top) { Rectangle().fill(T.outline).frame(height: 2) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(_ tab: MainTab, _ label: String, _ icon: String) -> some View {
        let on = app.tab == tab
        return Button {
            if !on { Feedback.play(.tap) }
            withAnimation(.easeOut(duration: 0.18)) { app.tab = tab }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 40, height: 32)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(on ? T.primarySoft : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(on ? T.outline : Color.clear, lineWidth: 2))
                Text(label).font(.isle(.caption2, .heavy))
            }
            .foregroundStyle(T.ink)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
