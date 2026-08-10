import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class LoginItemController: ObservableObject {
    private static let preferenceKey = "inface.launchAtLogin"

    @Published private(set) var isEnabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var lastError: String?
    @Published var wantsLaunchAtLogin: Bool

    init() {
        if UserDefaults.standard.object(forKey: Self.preferenceKey) == nil {
            wantsLaunchAtLogin = true
        } else {
            wantsLaunchAtLogin = UserDefaults.standard.bool(forKey: Self.preferenceKey)
        }
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            needsApproval = false
        case .requiresApproval:
            isEnabled = false
            needsApproval = true
        case .notRegistered, .notFound:
            isEnabled = false
            needsApproval = false
        @unknown default:
            isEnabled = false
            needsApproval = false
        }
    }

    /// Apply saved preference (call on launch).
    func applyPreference() {
        setEnabled(wantsLaunchAtLogin)
    }

    func setEnabled(_ enabled: Bool) {
        wantsLaunchAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: Self.preferenceKey)
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
