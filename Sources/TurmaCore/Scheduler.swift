import Foundation

/// O próximo lembrete previsto, para a linha "Próximo:" do menu.
public struct Upcoming: Equatable, Sendable {
    public var reminder: Reminder
    public var date: Date
}

/// Decide quando cada lembrete toca. Não tem timer próprio: o app chama `tick()`
/// (num timer, ao acordar o Mac etc.) e o agendador olha o relógio injetado.
/// Mostra um cartão por vez; quem vence enquanto há cartão na tela espera na fila.
public final class Scheduler {
    /// Disparo atrasado mais que isso (Mac dormindo, por exemplo) é descartado.
    public static let lateLimit: TimeInterval = 15 * 60

    /// Chamado quando um lembrete deve aparecer. Só um por vez: o próximo vem depois de `cardClosed()`.
    public var onFire: ((Reminder) -> Void)?

    public private(set) var config: Config
    /// O lembrete com cartão na tela agora.
    public private(set) var showing: Reminder?
    /// Lembretes que já venceram e esperam o cartão atual fechar.
    public private(set) var queue: [Reminder] = []
    public private(set) var pausedUntil: Date?

    private let calendar: Calendar
    private let now: () -> Date
    /// Próximo disparo regular de cada lembrete ligado, por id.
    private var nextFires: [String: Date] = [:]
    /// Disparos extras pedidos com "+N min", por id.
    private var snoozes: [String: Date] = [:]

    public init(config: Config, calendar: Calendar, now: @escaping () -> Date) {
        self.config = config
        self.calendar = calendar
        self.now = now
        recalculate()
    }

    public var isPaused: Bool {
        guard let pausedUntil else { return false }
        return now() < pausedUntil
    }

    private var activeReminders: [Reminder] { config.reminders.filter(\.enabled) }

    // MARK: - Tempo passando

    /// Processa tudo que venceu até agora: enfileira o que está em dia, descarta o muito atrasado.
    public func tick() {
        let current = now()
        if let pausedUntil {
            if current < pausedUntil { return }
            self.pausedUntil = nil
        }

        var due: [(date: Date, order: Int, reminder: Reminder)] = []
        for (order, reminder) in config.reminders.enumerated() where reminder.enabled {
            var dates: [Date] = []
            if let date = nextFires[reminder.id], date <= current {
                dates.append(date)
                nextFires[reminder.id] = reminder.nextFire(after: current, calendar: calendar)
            }
            if let date = snoozes[reminder.id], date <= current {
                dates.append(date)
                snoozes[reminder.id] = nil
            }
            // Se o horário normal e o adiado vencerem juntos, o lembrete aparece uma vez só.
            if let date = dates.filter({ current.timeIntervalSince($0) <= Self.lateLimit }).min() {
                due.append((date, order, reminder))
            }
        }

        due.sort { ($0.date, $0.order) < ($1.date, $1.order) }
        for item in due where !isWaitingOrShowing(item.reminder.id) {
            queue.append(item.reminder)
        }
        showNextIfIdle()
    }

    /// O Mac acordou: descarta o que atrasou demais e recalcula (o relógio pode ter mudado).
    public func didWake() {
        tick()
        recalculate()
    }

    /// Recalcula os próximos disparos regulares. Use quando o relógio ou o fuso mudar.
    public func recalculate() {
        // Durante a pausa, conta a partir do fim dela (um segundo antes, para incluir um disparo exatamente no fim).
        let reference = pausedUntil.map { max($0.addingTimeInterval(-1), now()) } ?? now()
        nextFires = [:]
        for reminder in activeReminders {
            nextFires[reminder.id] = reminder.nextFire(after: reference, calendar: calendar)
        }
    }

    // MARK: - Cartão

    /// O cartão atual fechou (feito, adiado, ignorado ou dispensado). Mostra o próximo da fila.
    public func cardClosed() {
        showing = nil
        showNextIfIdle()
    }

    /// Mostra um lembrete agora (menu "Testar lembrete"), mesmo pausado. Se houver cartão, entra na fila.
    public func trigger(_ reminder: Reminder) {
        queue.append(reminder)
        showNextIfIdle()
    }

    /// Faz o lembrete tocar de novo daqui a `minutes`. Não fecha o cartão: chame `cardClosed()` depois.
    public func snooze(_ id: String, minutes: Int) {
        snoozes[id] = now().addingTimeInterval(TimeInterval(minutes) * 60)
    }

    private func showNextIfIdle() {
        guard showing == nil, !queue.isEmpty else { return }
        let reminder = queue.removeFirst()
        showing = reminder
        onFire?(reminder)
    }

    private func isWaitingOrShowing(_ id: String) -> Bool {
        showing?.id == id || queue.contains { $0.id == id }
    }

    // MARK: - Pausa

    public func pause(until date: Date) {
        pausedUntil = date
        queue.removeAll()
        snoozes.removeAll()
        recalculate()
    }

    public func pauseOneHour() {
        pause(until: now().addingTimeInterval(60 * 60))
    }

    /// Pausa até as 06:00 do dia seguinte (no calendário, não "daqui a 24 h").
    public func pauseUntilTomorrowMorning() {
        let today = calendar.startOfDay(for: now())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow)
        else { return }
        pause(until: morning)
    }

    public func resume() {
        pausedUntil = nil
        recalculate()
    }

    // MARK: - Config

    /// Troca a config (arquivo recarregado). Mantém a pausa; tira da fila e dos adiados o que sumiu ou foi desligado.
    public func reload(_ config: Config) {
        self.config = config
        let active = Dictionary(activeReminders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        queue = queue.compactMap { active[$0.id] }
        snoozes = snoozes.filter { active[$0.key] != nil }
        recalculate()
    }

    // MARK: - Consultas

    /// O próximo lembrete previsto (regular ou adiado).
    public func next() -> Upcoming? {
        var best: Upcoming?
        for reminder in activeReminders {
            for date in [nextFires[reminder.id], snoozes[reminder.id]].compactMap({ $0 })
            where best == nil || date < best!.date {
                best = Upcoming(reminder: reminder, date: date)
            }
        }
        return best
    }

    /// Quando o app deve chamar `tick()` de novo: o próximo disparo ou o fim da pausa.
    public func nextWakeDate() -> Date? {
        [next()?.date, pausedUntil].compactMap { $0 }.min()
    }
}
