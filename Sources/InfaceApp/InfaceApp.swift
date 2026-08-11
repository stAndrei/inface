import InfaceCore
import SwiftUI

@main
struct InfaceApp: App {
    @StateObject private var model: AppModel
    @StateObject private var alertPresenter: AlertPresenter
    @StateObject private var loginItem = LoginItemController()

    init() {
        let router = CalendarSourceRouter(source: AppSettingsStore.load().calendarSource)
        let model = AppModel(calendarRouter: router)
        _model = StateObject(wrappedValue: model)
        _alertPresenter = StateObject(wrappedValue: AlertPresenter(model: model))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(loginItem)
                .onAppear {
                    loginItem.applyPreference()
                }
        } label: {
            Image(systemName: "calendar.badge.exclamationmark")
                .accessibilityLabel("Inface")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(loginItem)
        }
    }
}
