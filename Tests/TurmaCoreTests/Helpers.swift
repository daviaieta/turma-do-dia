import Foundation
@testable import TurmaCore

/// Fuso fixo para os testes não dependerem do Mac onde rodam (UTC-3, sem horário de verão).
let testTimeZone = TimeZone(secondsFromGMT: -3 * 3600)!

let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = testTimeZone
    calendar.locale = Locale(identifier: "pt_BR")
    return calendar
}()

/// "2026-10-19 07:00" -> Date no fuso de teste. 19/out/2026 é uma segunda-feira.
func date(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = testCalendar
    formatter.timeZone = testTimeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = text.count > 16 ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm"
    guard let result = formatter.date(from: text) else { fatalError("data de teste inválida: \(text)") }
    return result
}

/// Relógio de mentira: o teste move o tempo à mão.
final class FakeClock {
    var now: Date
    init(_ text: String) { now = date(text) }
    func set(_ text: String) { now = date(text) }
    func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }
}

func reminder(
    _ id: String,
    character: String = "gota",
    _ schedule: Schedule,
    enabled: Bool = true
) -> Reminder {
    Reminder(id: id, character: character, title: "Hora da", word: "teste!", subtitle: "", enabled: enabled, schedule: schedule)
}

/// Monta um Scheduler com relógio falso e guarda a ordem dos disparos.
final class Harness {
    let clock: FakeClock
    let scheduler: Scheduler
    private(set) var fired: [String] = []

    init(_ reminders: [Reminder], at start: String) {
        let clock = FakeClock(start)
        self.clock = clock
        scheduler = Scheduler(config: Config(reminders: reminders), calendar: testCalendar, now: { clock.now })
        scheduler.onFire = { [unowned self] in self.fired.append($0.id) }
    }

    /// Move o relógio e deixa o agendador olhar a hora, como o timer do app faria.
    func go(_ text: String) {
        clock.set(text)
        scheduler.tick()
    }
}
