//
//  CalendarManager.swift
//  Budget Expense
//

import Foundation
import EventKit
import Observation
import SwiftUI

@MainActor
@Observable
class CalendarManager {
    private let eventStore = EKEventStore()
    var isAuthorized = false
    var lastError: String?
    
    // Configuration
    var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "calendar_sync_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "calendar_sync_enabled") }
    }
    
    var isAlertEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "calendar_alert_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "calendar_alert_enabled") }
    }
    
    var lastSyncDate: Date? {
        get {
            let timestamp = UserDefaults.standard.double(forKey: "calendar_last_sync_timestamp")
            return timestamp == 0 ? nil : Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "calendar_last_sync_timestamp")
            }
        }
    }
    
    init() {
        // Default to true if not set
        if UserDefaults.standard.object(forKey: "calendar_sync_enabled") == nil {
            isSyncEnabled = true
        }
        if UserDefaults.standard.object(forKey: "calendar_alert_enabled") == nil {
            isAlertEnabled = true
        }
        checkStatus()
    }
    
    func checkStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = status == .authorized || status == .fullAccess
    }
    
    func requestAccess() async -> Bool {
        do {
            // For iOS 17+, use requestFullAccessToEvents
            if #available(iOS 17.0, *) {
                isAuthorized = try await eventStore.requestFullAccessToEvents()
            } else {
                isAuthorized = try await eventStore.requestAccess(to: .event)
            }
            return isAuthorized
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func syncAll(store: AppStore) async -> Int {
        var count = 0
        
        // 1. Sync Credit Cards
        for card in store.creditCards {
            let dueDate = store.billingCycleDueDate(for: card)
            let (start, end) = store.billingCycleDates(for: card)
            let df = DateFormatter(); df.dateFormat = "d MMM"
            let totalDue = store.totalDueThisMonth(for: card)
            
            let success = await syncToGoogleCalendar(
                title: "\(card.bank) - \(card.name)",
                dueDate: dueDate,
                notes: "Billing Cycle: \(df.string(from: start)) - \(df.string(from: end))\nTotal Due: \(formatCurrency(totalDue, currency: card.currency))"
            )
            if success { count += 1 }
        }
        
        // 2. Sync Outstanding Debts
        for debt in store.debts where !debt.isSettled {
            if let due = debt.dueDate {
                let success = await syncToGoogleCalendar(
                    title: "Pay \(debt.personName)",
                    dueDate: due,
                    notes: "Amount: \(debt.formattedAmount())\nNote: \(debt.note)"
                )
                if success { count += 1 }
            }
        }
        
        if count > 0 {
            lastSyncDate = Date()
        }
        
        return count
    }
    
    func syncToGoogleCalendar(title: String, dueDate: Date, notes: String) async -> Bool {
        guard isSyncEnabled else {
            print("🚫 Calendar Sync is disabled in settings.")
            return false
        }
        
        if !isAuthorized {
            let granted = await requestAccess()
            guard granted else { return false }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Payment Due: \(title)"
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(3600) // 1 hour duration
        event.notes = notes
        
        if isAlertEnabled {
            let alarm = EKAlarm(relativeOffset: -1800) // 30 minutes before
            event.addAlarm(alarm)
        }
        
        print("-------------------------------")
        print("📅 SYNCING TO CALENDAR:")
        print("TITLE: \(event.title ?? "No Title")")
        print("DATE:  \(event.startDate.formatted())")
        print("NOTES: \(event.notes ?? "No Notes")")
        print("-------------------------------")
        
        // Find the "Google" or default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Calendar event saved: \(title)")
            return true
        } catch {
            lastError = error.localizedDescription
            print("❌ Failed to save calendar event: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Environment Key

struct CalendarManagerKey: EnvironmentKey {
    @MainActor static let defaultValue = CalendarManager()
}

extension EnvironmentValues {
    var calendarManager: CalendarManager {
        get { self[CalendarManagerKey.self] }
        set { self[CalendarManagerKey.self] = newValue }
    }
}
