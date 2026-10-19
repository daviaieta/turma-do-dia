import Foundation

/// Quando um lembrete toca: horários fixos (`at`) ou intervalo (`every` minutos entre `from` e `to`).
/// `days` vazio ou ausente = todos os dias.
public struct Schedule: Codable, Equatable, Sendable {
    public var at: [String]?
    public var every: Int?
    public var from: String?
    public var to: String?
    public var days: [String]?

    public init(at: [String]? = nil, every: Int? = nil, from: String? = nil, to: String? = nil, days: [String]? = nil) {
        self.at = at
        self.every = every
        self.from = from
        self.to = to
        self.days = days
    }

    public static func at(_ times: [String], days: [String]? = nil) -> Schedule {
        Schedule(at: times, days: days)
    }

    public static func every(_ minutes: Int, from: String, to: String, days: [String]? = nil) -> Schedule {
        Schedule(every: minutes, from: from, to: to, days: days)
    }

    /// Dias aceitos e o `weekday` do Calendar gregoriano (1 = domingo).
    static let weekdays: [String: Int] = ["dom": 1, "seg": 2, "ter": 3, "qua": 4, "qui": 5, "sex": 6, "sab": 7]

    /// Confere o horário e devolve o primeiro erro, já com o id do lembrete.
    func validate(reminder id: String) throws(ConfigError) {
        for day in days ?? [] where Self.weekdays[day] == nil {
            throw .invalidDay(reminder: id, value: day)
        }
        let hasAt = !(at ?? []).isEmpty
        switch (hasAt, every) {
        case (true, .some):
            throw .bothAtAndEvery(reminder: id)
        case (false, nil):
            throw .missingSchedule(reminder: id)
        case (true, nil):
            for time in at ?? [] where minutesOfDay(time) == nil {
                throw .invalidTime(reminder: id, value: time)
            }
        case (false, .some(let minutes)):
            guard minutes > 0 else { throw .nonPositiveEvery(reminder: id, value: minutes) }
            guard let from, let to else { throw .missingWindow(reminder: id) }
            guard let start = minutesOfDay(from) else { throw .invalidTime(reminder: id, value: from) }
            guard let end = minutesOfDay(to) else { throw .invalidTime(reminder: id, value: to) }
            guard start <= end else { throw .invertedWindow(reminder: id, from: from, to: to) }
        }
    }

    /// Minutos do dia em que toca, em ordem. `nil` se o horário for inválido.
    func minutesOfDayList() -> [Int]? {
        if let at, !at.isEmpty, every == nil {
            let values = at.compactMap(minutesOfDay)
            return values.count == at.count ? values.sorted() : nil
        }
        if let every, every > 0, (at ?? []).isEmpty,
           let from, let to, let start = minutesOfDay(from), let end = minutesOfDay(to), start <= end {
            return Array(stride(from: start, through: end, by: every))
        }
        return nil
    }

    /// `weekday`s em que toca; `nil` se algum dia for inválido.
    func weekdaySet() -> Set<Int>? {
        guard let days, !days.isEmpty else { return Set(1...7) }
        let values = days.compactMap { Self.weekdays[$0] }
        return values.count == days.count ? Set(values) : nil
    }
}

/// "07:30" -> 450. Aceita "7:30". Rejeita "7h", "12:5", "24:00", segundos.
func minutesOfDay(_ text: String) -> Int? {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2,
          (1...2).contains(parts[0].count), parts[1].count == 2,
          parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
          let hour = Int(parts[0]), let minute = Int(parts[1]),
          (0...23).contains(hour), (0...59).contains(minute)
    else { return nil }
    return hour * 60 + minute
}
