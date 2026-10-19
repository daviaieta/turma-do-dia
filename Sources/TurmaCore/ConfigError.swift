import Foundation

/// Tudo que pode dar errado no arquivo de horários, com mensagem para o dono consertar.
public enum ConfigError: Error, Equatable, LocalizedError, Sendable {
    case invalidTime(reminder: String, value: String)
    case invalidDay(reminder: String, value: String)
    case unknownCharacter(reminder: String, value: String)
    case nonPositiveEvery(reminder: String, value: Int)
    case invertedWindow(reminder: String, from: String, to: String)
    case missingSchedule(reminder: String)
    case bothAtAndEvery(reminder: String)
    case missingWindow(reminder: String)
    case duplicateID(String)
    case invalidNumber(field: String, value: Int)
    case unreadable(path: String, reason: String)
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidTime(id, value):
            "Lembrete \"\(id)\": hora inválida \"\(value)\". Use HH:mm, de 00:00 a 23:59 (ex.: \"07:30\")."
        case let .invalidDay(id, value):
            "Lembrete \"\(id)\": dia inválido \"\(value)\". Use seg, ter, qua, qui, sex, sab ou dom."
        case let .unknownCharacter(id, value):
            "Lembrete \"\(id)\": personagem desconhecido \"\(value)\". Use um destes: "
                + CharacterID.allCases.map(\.rawValue).joined(separator: ", ") + "."
        case let .nonPositiveEvery(id, value):
            "Lembrete \"\(id)\": \"every\" precisa ser maior que zero (veio \(value))."
        case let .invertedWindow(id, from, to):
            "Lembrete \"\(id)\": a janela está invertida (from \(from) depois de to \(to))."
        case let .missingSchedule(id):
            "Lembrete \"\(id)\": falta o horário. Use \"at\" (lista de horas) ou \"every\" (minutos)."
        case let .bothAtAndEvery(id):
            "Lembrete \"\(id)\": use só um dos dois, \"at\" ou \"every\"."
        case let .missingWindow(id):
            "Lembrete \"\(id)\": \"every\" precisa de \"from\" e \"to\" (ex.: \"09:00\" e \"19:00\")."
        case let .duplicateID(id):
            "Tem dois lembretes com o id \"\(id)\". Cada um precisa de um id diferente."
        case let .invalidNumber(field, value):
            "\"\(field)\" precisa ser maior que zero (veio \(value))."
        case let .unreadable(path, reason):
            "Não consegui ler o arquivo de horários em \(path): \(reason)"
        case let .invalidJSON(detail):
            "O arquivo de horários não é um JSON válido: \(detail)"
        }
    }
}
