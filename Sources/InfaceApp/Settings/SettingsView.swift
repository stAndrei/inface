import InfaceCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loginItem: LoginItemController
    @State private var exchangePassword = ""
    @State private var showAdvanced = false

    var body: some View {
        Form {
            calendarSection
            alertsSection
            launchSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 480, height: model.settings.calendarSource == .exchange ? 560 : 360)
        .onAppear { loginItem.refresh() }
    }

    private var calendarSection: some View {
        Section("Календарь") {
            Picker("Источник", selection: $model.settings.calendarSource) {
                ForEach(CalendarSource.allCases) { source in
                    Text(source.displayName).tag(source)
                }
            }

            if model.settings.calendarSource == .exchange {
                exchangeInstructions
                TextField("Логин", text: $model.settings.exchangeUsername)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                SecureField("Пароль (код:пароль)", text: $exchangePassword)
                    .textContentType(.password)
                if showAdvanced {
                    TextField("Сервер EWS", text: $model.settings.exchangeEndpoint)
                        .autocorrectionDisabled()
                }
                Button(showAdvanced ? "Скрыть сервер" : "Дополнительно…") {
                    showAdvanced.toggle()
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                HStack {
                    Button(model.exchangeLoginInProgress ? "Вход…" : "Войти") {
                        Task {
                            await model.exchangeLogin(
                                username: model.settings.exchangeUsername,
                                password: exchangePassword
                            )
                            if model.authStatus == .authorized {
                                exchangePassword = ""
                            }
                        }
                    }
                    .disabled(
                        model.exchangeLoginInProgress
                            || model.settings.exchangeUsername.trimmingCharacters(in: .whitespaces).isEmpty
                            || exchangePassword.isEmpty
                    )
                    Button("Выйти") {
                        model.exchangeLogout()
                        exchangePassword = ""
                    }
                    .disabled(model.authStatus != .authorized)
                }
                if let error = model.lastError, model.settings.calendarSource == .exchange {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if model.authStatus == .authorized {
                    Text("Exchange подключён")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var exchangeInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подключение Exchange")
                .font(.callout.weight(.semibold))
            Text("Логин: имя@ozon.ru (например, petrovan@ozon.ru)")
            Text("Пароль: строка код:пароль из бота @mail-bot в Chatzone — не обычный пароль учётки.")
            Text("Получите код у @mail-bot и введите в поле пароля, например: КОД:ваш_пароль")
            Text("При смене пароля учётки (~раз в 3 мес.) обновите код и пароль здесь.")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    private var alertsSection: some View {
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
    }

    private var launchSection: some View {
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
    }

    private var aboutSection: some View {
        Section("О приложении") {
            Text("Inface — напоминания о встречах, которые нельзя пропустить.")
                .foregroundStyle(.secondary)
        }
    }
}
