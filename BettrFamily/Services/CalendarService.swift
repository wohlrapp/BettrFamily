import Foundation
import EventKit

@MainActor
final class CalendarService: ObservableObject {
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var isAuthorized = false

    private let store = EKEventStore()

    init() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = status == .fullAccess || status == .authorized
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                loadUpcomingEvents()
            }
        } catch {
            print("Calendar access error: \(error)")
        }
    }

    private var familyCalendar: EKCalendar? {
        store.calendars(for: .event).first { $0.title == "Family" }
    }

    func loadUpcomingEvents() {
        guard isAuthorized, let calendar = familyCalendar else {
            upcomingEvents = []
            return
        }

        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: 14, to: now) else { return }

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: [calendar])
        let ekEvents = store.events(matching: predicate)

        upcomingEvents = ekEvents.prefix(20).map { event in
            CalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location
            )
        }
    }
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
}
