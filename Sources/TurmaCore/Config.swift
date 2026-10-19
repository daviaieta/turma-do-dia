import Foundation

/// O arquivo de horários inteiro (`reminders.json`).
public struct Config: Codable, Equatable, Sendable {
    public var reminders: [Reminder]
    /// Quanto tempo o cartão fica na tela antes de fechar sozinho.
    public var cardSeconds: Int
    /// Quanto o botão "+N min" adia.
    public var snoozeMinutes: Int

    public init(reminders: [Reminder], cardSeconds: Int = 90, snoozeMinutes: Int = 10) {
        self.reminders = reminders
        self.cardSeconds = cardSeconds
        self.snoozeMinutes = snoozeMinutes
    }

    enum CodingKeys: String, CodingKey { case reminders, cardSeconds, snoozeMinutes }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reminders = try c.decode([Reminder].self, forKey: .reminders)
        cardSeconds = try c.decodeIfPresent(Int.self, forKey: .cardSeconds) ?? 90
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 10
    }

    public func validate() throws(ConfigError) {
        guard cardSeconds > 0 else { throw .invalidNumber(field: "cardSeconds", value: cardSeconds) }
        guard snoozeMinutes > 0 else { throw .invalidNumber(field: "snoozeMinutes", value: snoozeMinutes) }
        var seen = Set<String>()
        for reminder in reminders {
            guard seen.insert(reminder.id).inserted else { throw .duplicateID(reminder.id) }
            try reminder.validate()
        }
    }

    /// Lê, decodifica e valida. Qualquer problema vira um `ConfigError` com mensagem em português.
    public static func load(from url: URL) throws(ConfigError) -> Config {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            let reason = (error as NSError).code == NSFileReadNoSuchFileError ? "o arquivo não existe." : error.localizedDescription
            throw .unreadable(path: url.path, reason: reason)
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws(ConfigError) -> Config {
        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch let error as DecodingError {
            throw .invalidJSON(describe(error))
        } catch {
            throw .invalidJSON(error.localizedDescription)
        }
        try config.validate()
        return config
    }

    /// JSON para uma pessoa editar: chaves na ordem de leitura (id, personagem, textos, horário)
    /// e cada `schedule` numa linha só. O `JSONEncoder` não garante ordem de chaves, por isso é montado à mão;
    /// os valores passam pelo `JSONEncoder` para o escape de texto ficar certo.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        func json(_ value: some Encodable) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        func pair(_ key: String, _ value: some Encodable) throws -> String {
            "\"\(key)\": \(try json(value))"
        }

        var lines = ["{", "  \(try pair("cardSeconds", cardSeconds)),", "  \(try pair("snoozeMinutes", snoozeMinutes)),", "  \"reminders\": ["]
        for (index, r) in reminders.enumerated() {
            let s = r.schedule
            var schedule: [String] = []
            if let at = s.at { schedule.append(try pair("at", at)) }
            if let every = s.every { schedule.append(try pair("every", every)) }
            if let from = s.from { schedule.append(try pair("from", from)) }
            if let to = s.to { schedule.append(try pair("to", to)) }
            if let days = s.days { schedule.append(try pair("days", days)) }
            let fields = [
                try pair("id", r.id), try pair("character", r.character), try pair("title", r.title),
                try pair("word", r.word), try pair("subtitle", r.subtitle), try pair("enabled", r.enabled),
                "\"schedule\": { \(schedule.joined(separator: ", ")) }",
            ]
            lines.append("    {")
            lines.append(fields.map { "      " + $0 }.joined(separator: ",\n"))
            lines.append(index == reminders.count - 1 ? "    }" : "    },")
        }
        lines += ["  ]", "}", ""]
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// Cria o arquivo com `defaults` se ele ainda não existe. Nunca sobrescreve: devolve `false` se já havia arquivo.
    @discardableResult
    public static func writeDefaultsIfMissing(to url: URL) throws -> Bool {
        if FileManager.default.fileExists(atPath: url.path) { return false }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try defaults.encoded().write(to: url, options: .withoutOverwriting)
        return true
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ codingPath: [any CodingKey]) -> String {
            let text = codingPath.map { key in
                key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)"
            }.joined()
            let trimmed = text.hasPrefix(".") ? String(text.dropFirst()) : text
            return trimmed.isEmpty ? "na raiz do arquivo" : "em \(trimmed)"
        }
        switch error {
        case let .keyNotFound(key, context):
            return "falta o campo \"\(key.stringValue)\" \(path(context.codingPath))."
        case let .typeMismatch(type, context):
            return "tipo errado \(path(context.codingPath)) (esperava \(typeName(type)))."
        case let .valueNotFound(type, context):
            return "valor vazio \(path(context.codingPath)) (esperava \(typeName(type)))."
        case let .dataCorrupted(context):
            if context.codingPath.isEmpty {
                // Erro de sintaxe: vírgula, aspas ou chave faltando/sobrando.
                let detail = (context.underlyingError as NSError?)?.debugDescription ?? context.debugDescription
                return "confira vírgulas, aspas e chaves. Detalhe: \(detail)"
            }
            return "valor inválido \(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func typeName(_ type: Any.Type) -> String {
        switch type {
        case is String.Type: "texto entre aspas"
        case is Int.Type: "número inteiro"
        case is Bool.Type: "true ou false"
        case is [String].Type: "lista de textos"
        default: "\(type)"
        }
    }
}
