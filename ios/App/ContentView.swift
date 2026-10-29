import SwiftUI
import UniformTypeIdentifiers
import NetworkExtension

struct VPNProfile: Identifiable, Hashable {
    let name: String
    let url: URL

    var id: String { name }
    var configuration: String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    var hasIPv6DefaultRoute: Bool {
        configuration
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("allowedips") }
            .flatMap { $0.components(separatedBy: "=").dropFirst().joined().components(separatedBy: ",") }
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "::/0" }
    }
}

@MainActor
struct ContentView: View {
    @State private var profiles: [VPNProfile] = []
    @State private var selectedProfileName = ""
    @State private var showImporter = false
    @State private var showIPv6Warning = false
    @State private var showAlert = false
    @State private var alertTitle = "FreeRoute VPN"
    @State private var alertMessage = ""
    @State private var status = "Ожидает настройки"
    @State private var isBusy = false
    @State private var activeManager: NETunnelProviderManager?

    private let accent = Color(red: 0.32, green: 0.58, blue: 0.95)
    private let background = Color(red: 0.04, green: 0.06, blue: 0.12)

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 7) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(accent)
                            Text("FreeRoute")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Личный VPN-клиент")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.62))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("СОСТОЯНИЕ")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.white.opacity(0.52))
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(status.contains("подключён") ? Color.green : accent)
                                    .frame(width: 10, height: 10)
                                Text(status)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer(minLength: 0)
                                if isBusy {
                                    ProgressView().tint(.white)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ПРОФИЛЬ / СЕРВЕР")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.white.opacity(0.52))

                            if profiles.isEmpty {
                                Text("Пока нет профилей. Добавь собственную конфигурацию WireGuard (.conf).")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.68))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                            } else {
                                Picker("Профиль", selection: $selectedProfileName) {
                                    ForEach(profiles) { profile in
                                        Text(profile.name).tag(profile.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                                if let profile = selectedProfile {
                                    Label(
                                        profile.hasIPv6DefaultRoute ? "В конфигурации есть маршрут IPv6" : "Маршрут IPv6 отсутствует",
                                        systemImage: profile.hasIPv6DefaultRoute ? "checkmark.shield" : "exclamationmark.triangle"
                                    )
                                    .font(.footnote)
                                    .foregroundStyle(profile.hasIPv6DefaultRoute ? Color.green : Color.orange)
                                }
                            }

                            Button {
                                showImporter = true
                            } label: {
                                Label("Добавить профиль", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(isBusy)
                        }

                        VStack(spacing: 12) {
                            Button {
                                connectTapped()
                            } label: {
                                Label("Подключить VPN", systemImage: "power")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.12, green: 0.48, blue: 0.34)))
                            .disabled(isBusy || selectedProfile == nil || status.contains("подключён"))

                            Button {
                                Task { await disconnect() }
                            } label: {
                                Label("Отключить VPN", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.25, green: 0.29, blue: 0.38)))
                            .disabled(isBusy || !status.contains("подключён"))
                        }

                        Text("Имя профиля не подтверждает страну выхода. Её определяет удалённый сервер. Профили хранятся локально на этом устройстве.")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)

                        Button("О лицензиях и движке") {
                            alertTitle = "Открытое ПО"
                            alertMessage = "FreeRoute использует WireGuardKit как встроенный сетевой движок. Интерфейс и управление профилями разрабатываются в репозитории FreeRoute. Условия и уведомления включены в ресурс THIRD_PARTY_NOTICES.txt."
                            showAlert = true
                        }
                        .font(.footnote)
                        .foregroundStyle(accent)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false,
                onCompletion: importResult
            )
            .confirmationDialog(
                "Возможна утечка IPv6",
                isPresented: $showIPv6Warning,
                titleVisibility: .visible
            ) {
                Button("Продолжить с этим риском", role: .destructive) {
                    Task { await connectSelectedProfile() }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Эта конфигурация не направляет IPv6 через VPN. Часть сайтов может увидеть исходное подключение и его страну. Даже при наличии маршрута IPv6 работу сервера необходимо проверить.")
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Закрыть", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .task {
                reloadProfiles()
                await refreshStatus()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var selectedProfile: VPNProfile? {
        profiles.first { $0.name == selectedProfileName }
    }

    private func profileDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents.appendingPathComponent("Profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var protectedDirectory = directory
        try? protectedDirectory.setResourceValues(resourceValues)
        return directory
    }

    private func reloadProfiles(select name: String? = nil) {
        do {
            let directory = try profileDirectory()
            profiles = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "conf" }
            .map { VPNProfile(name: $0.deletingPathExtension().lastPathComponent, url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            let saved = name ?? UserDefaults.standard.string(forKey: "freeroute.selectedProfile")
            selectedProfileName = profiles.first(where: { $0.name == saved })?.name ?? profiles.first?.name ?? ""
            UserDefaults.standard.set(selectedProfileName, forKey: "freeroute.selectedProfile")
        } catch {
            alertTitle = "Ошибка профилей"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func importResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                throw ProfileError.notUtf8
            }
            try validateProfile(text)

            let base = safeProfileName(url.deletingPathExtension().lastPathComponent)
            let directory = try profileDirectory()
            let destination = uniqueDestination(base: base, directory: directory)
            try data.write(to: destination, options: .completeFileProtectionUnlessOpen)
            reloadProfiles(select: destination.deletingPathExtension().lastPathComponent)
            status = "Профиль импортирован"
        } catch {
            alertTitle = "Не удалось импортировать профиль"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func validateProfile(_ text: String) throws {
        guard text.count < 65_536 else { throw ProfileError.fileTooLarge }
        guard text.range(of: #"(?im)^\s*\[Interface\]\s*$"#, options: .regularExpression) != nil,
              text.range(of: #"(?im)^\s*\[Peer\]\s*$"#, options: .regularExpression) != nil,
              text.range(of: #"(?im)^\s*PrivateKey\s*=\s*\S+"#, options: .regularExpression) != nil,
              text.range(of: #"(?im)^\s*PublicKey\s*=\s*\S+"#, options: .regularExpression) != nil,
              text.range(of: #"(?im)^\s*Endpoint\s*=\s*\S+"#, options: .regularExpression) != nil,
              text.range(of: #"(?im)^\s*AllowedIPs\s*=\s*\S+"#, options: .regularExpression) != nil else {
            throw ProfileError.invalidFormat
        }
    }

    private func safeProfileName(_ value: String) -> String {
        let clean = value
            .replacingOccurrences(of: #"[^A-Za-z0-9._ -]"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ._-"))
        return String((clean.isEmpty ? "Profile" : clean).prefix(48))
    }

    private func uniqueDestination(base: String, directory: URL) -> URL {
        var fileName = base
        var suffix = 2
        var destination = directory.appendingPathComponent(fileName).appendingPathExtension("conf")
        while FileManager.default.fileExists(atPath: destination.path) {
            fileName = "\(base)-\(suffix)"
            destination = directory.appendingPathComponent(fileName).appendingPathExtension("conf")
            suffix += 1
        }
        return destination
    }

    private func connectTapped() {
        guard let profile = selectedProfile else { return }
        UserDefaults.standard.set(profile.name, forKey: "freeroute.selectedProfile")
        if !profile.hasIPv6DefaultRoute {
            showIPv6Warning = true
        } else {
            Task { await connectSelectedProfile() }
        }
    }

    private func connectSelectedProfile() async {
        guard let profile = selectedProfile else { return }
        isBusy = true
        status = "Подготавливаем VPN…"
        defer { isBusy = false }

        do {
            let managers = try await loadAllManagers()
            let manager = managers.first ?? NETunnelProviderManager()
            let tunnelProtocol = NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = "com.arturwarlord.freeroute.network-extension"
            tunnelProtocol.serverAddress = profile.name

            // Store the secret config in the app/extension shared Keychain group.
            // VPN preferences contain only a persistent reference, never the private key.
            let previousReference = (manager.protocolConfiguration as? NETunnelProviderProtocol)?.passwordReference
            let newReference = try ProfileKeychain.save(profile.configuration, profileName: profile.name)
            tunnelProtocol.passwordReference = newReference
            tunnelProtocol.providerConfiguration = nil
            manager.protocolConfiguration = tunnelProtocol
            manager.localizedDescription = "FreeRoute VPN"
            manager.isEnabled = true

            do {
                try await saveManager(manager)
            } catch {
                ProfileKeychain.delete(reference: newReference)
                throw error
            }

            if let previousReference, previousReference != newReference {
                ProfileKeychain.delete(reference: previousReference)
            }
            try await reloadManager(manager)
            try manager.connection.startVPNTunnel()
            activeManager = manager
            status = "Запуск VPN…"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await refreshStatus()
        } catch {
            status = "Не удалось подключиться"
            alertTitle = "Ошибка VPN"
            alertMessage = error.localizedDescription + "\n\nНа iPhone для Packet Tunnel требуется подписанное приложение с разрешением Network Extension."
            showAlert = true
        }
    }

    private func disconnect() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let managers = try await loadAllManagers()
            managers.first?.connection.stopVPNTunnel()
            status = "VPN отключён"
        } catch {
            alertTitle = "Не удалось отключить VPN"
            alertMessage = error.localizedDescription
            showAlert = true
        }
        await refreshStatus()
    }

    private func refreshStatus() async {
        do {
            let manager = try await loadAllManagers().first
            activeManager = manager
            guard let connection = manager?.connection else {
                status = profiles.isEmpty ? "Ожидает настройки" : "Готов к подключению"
                return
            }
            switch connection.status {
            case .connected:
                status = "VPN подключён"
            case .connecting, .reasserting:
                status = "VPN подключается…"
            case .disconnecting:
                status = "VPN отключается…"
            default:
                status = profiles.isEmpty ? "Ожидает настройки" : "VPN отключён"
            }
        } catch {
            status = profiles.isEmpty ? "Ожидает настройки" : "VPN отключён"
        }
    }

    private func loadAllManagers() async throws -> [NETunnelProviderManager] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[NETunnelProviderManager], Error>) in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: managers ?? [])
                }
            }
        }
    }

    private func saveManager(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func reloadManager(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private enum ProfileError: LocalizedError {
    case notUtf8
    case fileTooLarge
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .notUtf8: return "Файл должен быть текстовой UTF-8 конфигурацией."
        case .fileTooLarge: return "Файл конфигурации слишком большой."
        case .invalidFormat: return "Не найдены обязательные секции и параметры WireGuard."
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .background(Color.white.opacity(configuration.isPressed ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
