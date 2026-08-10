import InfaceCore
import SwiftUI

@main
struct InfaceApp: App {
    @StateObject private var model: AppModel
    @StateObject private var alertPresenter: AlertPresenter

    init() {
        let calendar = EventKitCalendarService()
        let model = AppModel(calendar: calendar)
        _model = StateObject(wrappedValue: model)
        _alertPresenter = StateObject(wrappedValue: AlertPresenter(model: model))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: "calendar.badge.exclamationmark")
                .accessibilityLabel("Inface")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
