import SwiftUI
import SwiftData
import UserNotifications

@main
struct IsleApp: App {
    let container: ModelContainer
    @State private var app = AppModel()

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: TaskItem.self, Habit.self, HabitLog.self, FreezeDay.self, DayCheckin.self,
                                   JournalEntry.self, IsleState.self, AppSettings.self,
                                   NoteList.self, ListEntry.self, Routine.self)
        } catch {
            // Fall back to memory so the app still opens; data won't persist this launch.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            c = try! ModelContainer(for: TaskItem.self, Habit.self, HabitLog.self, FreezeDay.self, DayCheckin.self,
                                    JournalEntry.self, IsleState.self, AppSettings.self,
                                    NoteList.self, ListEntry.self, Routine.self, configurations: config)
        }
        container = c
        NotificationDelegate.shared.container = c
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        IsleNotifications.registerCategories()
        SideSwitcher.shared.prepareLaunch()
    }

    var body: some Scene {
        WindowGroup {
            SideHost(isleContainer: container)
                .environment(app)
        }
    }
}

/// Handles the Done / Later buttons on notifications.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    var container: ModelContainer?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        let action = response.actionIdentifier
        let container = self.container
        Task { @MainActor in
            // Tapping a reminder opens the side it belongs to.
            if action == UNNotificationDefaultActionIdentifier {
                SideSwitcher.shared.jump(to: id.hasPrefix("prime.") ? .prime : .isle)
            }
            if let container, action == "DONE" || action == "LATER" {
                NotificationDelegate.handle(id: id, action: action, container: container)
            }
            completionHandler()
        }
    }

    @MainActor
    static func handle(id: String, action: String, container: ModelContainer) {
        let parts = id.split(separator: "-")
        guard parts.count >= 3 else { return }
        let kind = String(parts[0])
        let uuidString = parts.dropFirst().dropLast().joined(separator: "-")
        guard let uuid = UUID(uuidString: uuidString) else { return }
        let store = Store(context: container.mainContext)
        if kind == "task", let task = store.allTasks().first(where: { $0.id == uuid }) {
            if action == "DONE", !task.isDone { store.toggle(task) }
            if action == "LATER", let start = task.startMinutes { task.startMinutes = min(23 * 60, start + 60); store.save() }
        } else if kind == "habit", action == "DONE", let habit = store.allHabits().first(where: { $0.id == uuid }) {
            if store.log(for: habit, day: Day.today, logs: store.allLogs()) == nil {
                store.toggle(habit, lowBattery: false)
            }
        }
    }
}
