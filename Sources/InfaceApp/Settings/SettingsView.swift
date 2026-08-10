import InfaceCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loginItem: LoginItemController

    var body: some View {
        Form {
            Section("Оповещения") {
                Stepper(
                    value: Binding(
                        get: { Int(model.settings.alertLeadTime / 60) },
                        set: { model.settings.alertLeadTime = TimeInterval($0 * 60) }
                    ),
                    in: 1...30
                ) {
                    Text("За сколько минут предупреждать: \(Int(model.settings.alertLeadTime / 60))")
                }
                Toggle("Пауза оповещений", isOn: Binding(
                    get: { model.settings.alertsPaused },
                    set: { model.settings.alertsPaused = $0 }
                ))
            }

            Section("Запуск") {
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { loginItem.wantsLaunchAtLogin },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.needsApproval {
                    Text("Разрешите Inface в «Системные настройки → Основные → Объекты входа».")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Открыть объекты входа") {
                        loginItem.openLoginItemsSettings()
                    }
                }
                if let error = loginItem.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section("О приложении") {
                Text("Inface — напоминания о встречах, которые нельзя пропустить.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
        .onAppear { loginItem.refresh() }
    }
}
