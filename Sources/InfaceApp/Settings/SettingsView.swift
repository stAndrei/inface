import InfaceCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

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
            Section("О приложении") {
                Text("Inface — напоминания о встречах, которые нельзя пропустить.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 240)
    }
}
