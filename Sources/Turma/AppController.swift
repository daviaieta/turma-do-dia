import AppKit
import os
import ServiceManagement
import TurmaCore

private let log = Logger(subsystem: "br.com.daviaieta.turma", category: "app")

/// Liga tudo: arquivo de horários, agendador, histórico, item da barra de menu e o cartão.
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Cartões do menu "Testar lembrete" ganham este prefixo no id: não contam no histórico e o "+N min" não reagenda.
    private static let testPrefix = "teste-"

    private let options: LaunchOptions
    private let calendar = Calendar.autoupdatingCurrent
    private var config = Config(reminders: [])
    /// Mensagem do último erro ao ler o arquivo de horários (nil = tudo certo).
    private var configProblem: String?

    private var scheduler: Scheduler!
    private var history: History!
    private var card: CardController?
    private var timer: Timer?

    private var statusItem: NSStatusItem!
    private let nextItem = NSMenuItem()
    private let pausedItem = NSMenuItem()
    private let todayItem = NSMenuItem()
    private let problemItem = NSMenuItem()
    private var resumeItem: NSMenuItem!
    private var loginItem: NSMenuItem!

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init(options: LaunchOptions) {
        self.options = options
    }

    // MARK: - Início

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(at: options.stateDirectory, withIntermediateDirectories: true)
            try Config.writeDefaultsIfMissing(to: options.configURL)
        } catch {
            log.error("não consegui criar o arquivo de horários: \(error.localizedDescription, privacy: .public)")
        }
        loadConfig()

        history = History(directory: options.stateDirectory)
        if let problem = history.loadProblem { log.error("\(problem, privacy: .public)") }

        scheduler = Scheduler(config: config, calendar: calendar, now: Date.init)
        scheduler.onFire = { [weak self] reminder in self?.present(reminder) }

        setUpStatusItem()
        observeSystem()
        scheduleTimer()

        if let problem = configProblem {
            showAlert(title: "O arquivo de horários tem um erro", message: problem + "\n\nNenhum lembrete vai tocar até corrigir e escolher \"Recarregar horários\".")
        }
        if let character = options.showCharacter {
            test(character)
        }
    }

    /// Lê o arquivo. Se der erro na abertura do app, segue sem lembretes (melhor que tocar horários errados).
    @discardableResult
    private func loadConfig() -> Bool {
        do {
            config = try Config.load(from: options.configURL)
            configProblem = nil
            return true
        } catch {
            configProblem = error.localizedDescription
            log.error("\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Relógio

    /// Um timer só, apontado para o próximo disparo, revisto a cada minuto no máximo
    /// (assim uma mudança de hora do sistema não passa despercebida por muito tempo).
    private func scheduleTimer() {
        timer?.invalidate()
        let wait = scheduler.nextWakeDate().map { $0.timeIntervalSinceNow } ?? 60
        let interval = min(max(wait, 0.2), 60)
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(timerFired), userInfo: nil, repeats: false)
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func timerFired() {
        scheduler.tick()
        scheduleTimer()
    }

    private func observeSystem() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(clockDidChange), name: name, object: nil)
        }
    }

    @objc private func systemDidWake() {
        scheduler.didWake()
        scheduleTimer()
    }

    @objc private func clockDidChange() {
        scheduler.recalculate()
        scheduleTimer()
    }

    // MARK: - Cartão

    private func present(_ reminder: Reminder) {
        let isTest = reminder.id.hasPrefix(Self.testPrefix)
        card = CardController(
            reminder: reminder,
            cardSeconds: config.cardSeconds,
            snoozeMinutes: config.snoozeMinutes,
            slow: options.slow,
            onResult: { [weak self] result in self?.record(result, for: reminder, isTest: isTest) },
            onClosed: { [weak self] in self?.cardDidClose() }
        )
        card?.open()
    }

    private func record(_ result: CardController.Result, for reminder: Reminder, isTest: Bool) {
        if case .snoozed = result, !isTest {
            scheduler.snooze(reminder.id, minutes: config.snoozeMinutes)
        }
        guard !isTest else { return }
        let outcome: Outcome? = switch result {
        case .done: .done
        case .snoozed: .snoozed
        case .ignored: .ignored
        case .dismissed: nil  // fechado com Esc: não conta como feito, adiado nem ignorado
        }
        guard let outcome else { return }
        do {
            try history.record(outcome, at: Date(), calendar: calendar)
        } catch {
            log.error("não consegui gravar o histórico: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func cardDidClose() {
        // Zera antes: `cardClosed()` pode abrir o próximo da fila na mesma hora.
        card = nil
        scheduler.cardClosed()
        scheduleTimer()
    }

    private func test(_ character: CharacterID) {
        let base = config.reminders.first { $0.character == character.rawValue }
            ?? Config.defaults.reminders.first { $0.character == character.rawValue }
        guard var reminder = base else { return }
        reminder.id = Self.testPrefix + reminder.id
        scheduler.trigger(reminder)
    }

    // MARK: - Menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Turma do Dia")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Turma do Dia"

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        for item in [nextItem, pausedItem, todayItem, problemItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let testMenu = NSMenu()
        for character in CharacterID.allCases {
            let item = NSMenuItem(title: character.displayName, action: #selector(testFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = character.rawValue
            testMenu.addItem(item)
        }
        let testItem = NSMenuItem(title: "Testar lembrete", action: nil, keyEquivalent: "")
        testItem.submenu = testMenu
        menu.addItem(testItem)
        menu.addItem(.separator())

        menu.addItem(action("Pausar 1 h", #selector(pauseOneHour)))
        menu.addItem(action("Pausar até amanhã", #selector(pauseUntilTomorrow)))
        resumeItem = action("Retomar", #selector(resume))
        menu.addItem(resumeItem)
        menu.addItem(.separator())

        menu.addItem(action("Abrir arquivo de horários", #selector(openConfigFile)))
        menu.addItem(action("Recarregar horários", #selector(reloadConfig)))
        menu.addItem(.separator())

        loginItem = action("Abrir ao iniciar o Mac", #selector(toggleOpenAtLogin))
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let quit = action("Sair", #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)

        statusItem.menu = menu
        refreshMenu()
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        timeFormatter.timeZone = calendar.timeZone
        let now = Date()

        if let next = scheduler.next() {
            let name = next.reminder.characterID?.displayName ?? next.reminder.character
            nextItem.title = "Próximo: \(name) às \(timeFormatter.string(from: next.date))\(dayHint(for: next.date, now: now))"
        } else {
            nextItem.title = "Próximo: nenhum lembrete ligado"
        }

        if scheduler.isPaused, let until = scheduler.pausedUntil {
            pausedItem.title = "Pausado até \(timeFormatter.string(from: until))\(dayHint(for: until, now: now))"
            pausedItem.isHidden = false
        } else {
            pausedItem.isHidden = true
        }
        resumeItem.isEnabled = scheduler.isPaused

        let done = history.todayCounts(now: now, calendar: calendar).done
        todayItem.title = "Hoje: \(done) \(done == 1 ? "feito" : "feitos")"

        problemItem.title = "Arquivo de horários com erro (veja Recarregar)"
        problemItem.isHidden = configProblem == nil

        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    /// " (amanhã)" ou " (qua)" quando a data não é hoje.
    private func dayHint(for date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return " (amanhã)"
        }
        let names = ["dom", "seg", "ter", "qua", "qui", "sex", "sab"]
        return " (\(names[calendar.component(.weekday, from: date) - 1]))"
    }

    // MARK: - Ações do menu

    @objc private func testFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let character = CharacterID(rawValue: id) else { return }
        test(character)
    }

    @objc private func pauseOneHour() {
        scheduler.pauseOneHour()
        scheduleTimer()
    }

    @objc private func pauseUntilTomorrow() {
        scheduler.pauseUntilTomorrowMorning()
        scheduleTimer()
    }

    @objc private func resume() {
        scheduler.resume()
        scheduleTimer()
    }

    @objc private func openConfigFile() {
        NSWorkspace.shared.open(options.configURL)
    }

    @objc private func reloadConfig() {
        let previous = config
        if loadConfig() {
            scheduler.reload(config)
            scheduleTimer()
        } else {
            config = previous
            showAlert(title: "Não recarreguei os horários", message: (configProblem ?? "") + "\n\nOs horários de antes continuam valendo.")
        }
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            showAlert(
                title: "Não deu para mudar \"Abrir ao iniciar o Mac\"",
                message: error.localizedDescription + "\n\nIsso só funciona com o app aberto a partir do Turma.app.")
        }
        refreshMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
