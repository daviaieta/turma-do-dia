import Foundation

/// Um passo da rotina, com o personagem que aparece no cartão.
public struct Reminder: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var character: String
    /// Linha de cima do cartão, ex.: "Hora da".
    public var title: String
    /// A palavra em destaque, ex.: "água!".
    public var word: String
    public var subtitle: String
    public var enabled: Bool
    public var schedule: Schedule

    public init(
        id: String, character: String, title: String, word: String,
        subtitle: String = "", enabled: Bool = true, schedule: Schedule
    ) {
        self.id = id
        self.character = character
        self.title = title
        self.word = word
        self.subtitle = subtitle
        self.enabled = enabled
        self.schedule = schedule
    }

    enum CodingKeys: String, CodingKey {
        case id, character, title, word, subtitle, enabled, schedule
    }

    // Decoder à mão só para `subtitle` e `enabled` serem opcionais no arquivo.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        character = try c.decode(String.self, forKey: .character)
        title = try c.decode(String.self, forKey: .title)
        word = try c.decode(String.self, forKey: .word)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        schedule = try c.decode(Schedule.self, forKey: .schedule)
    }

    public var characterID: CharacterID? { CharacterID(rawValue: character) }

    public func validate() throws(ConfigError) {
        guard characterID != nil else { throw .unknownCharacter(reminder: id, value: character) }
        try schedule.validate(reminder: id)
    }

    /// Primeiro disparo estritamente depois de `after`. `nil` se o horário for inválido.
    /// Olha até 8 dias à frente: cobre um lembrete semanal que acabou de tocar.
    public func nextFire(after: Date, calendar: Calendar) -> Date? {
        guard let minutes = schedule.minutesOfDayList(), !minutes.isEmpty,
              let weekdays = schedule.weekdaySet() else { return nil }
        let today = calendar.startOfDay(for: after)
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
            for minute in minutes {
                // bySettingHour lida com o horário de verão melhor que somar segundos.
                guard let candidate = calendar.date(
                    bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day
                ) else { continue }
                if candidate > after { return candidate }
            }
        }
        return nil
    }
}
