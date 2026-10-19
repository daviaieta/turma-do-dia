import Foundation

/// O que aconteceu com um cartão.
public enum Outcome: String, Codable, Sendable {
    /// Botão "Feito".
    case done = "feito"
    /// Botão "+N min".
    case snoozed = "adiado"
    /// O cartão fechou sozinho.
    case ignored = "ignorado"
}

public struct DayCounts: Codable, Equatable, Sendable {
    public var done: Int
    public var snoozed: Int
    public var ignored: Int

    public init(done: Int = 0, snoozed: Int = 0, ignored: Int = 0) {
        self.done = done
        self.snoozed = snoozed
        self.ignored = ignored
    }

    enum CodingKeys: String, CodingKey {
        case done = "feito", snoozed = "adiado", ignored = "ignorado"
    }
}

/// Contagem diária em `historico.json`. Fica só no disco local; nada vai para a rede.
public final class History {
    public static let fileName = "historico.json"

    public let fileURL: URL
    /// Preenchido se o arquivo existia mas não deu para ler. O app segue com o histórico vazio.
    public private(set) var loadProblem: String?

    private struct File: Codable {
        var version = 1
        /// Chave "AAAA-MM-DD" no calendário do usuário.
        var days: [String: DayCounts] = [:]
    }

    private var file = File()

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent(Self.fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            file = try JSONDecoder().decode(File.self, from: data)
        } catch {
            // Guarda o arquivo ruim ao lado em vez de apagar, e começa do zero.
            loadProblem = "historico.json estava corrompido; guardei uma cópia em historico.corrompido.json."
            let backup = directory.appendingPathComponent("historico.corrompido.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
        }
    }

    public func record(_ outcome: Outcome, at date: Date, calendar: Calendar) throws {
        let key = Self.dayKey(date, calendar: calendar)
        var counts = file.days[key] ?? DayCounts()
        switch outcome {
        case .done: counts.done += 1
        case .snoozed: counts.snoozed += 1
        case .ignored: counts.ignored += 1
        }
        file.days[key] = counts
        try save()
    }

    public func counts(on date: Date, calendar: Calendar) -> DayCounts {
        file.days[Self.dayKey(date, calendar: calendar)] ?? DayCounts()
    }

    public func todayCounts(now: Date, calendar: Calendar) -> DayCounts {
        counts(on: now, calendar: calendar)
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: fileURL, options: .atomic)
        loadProblem = nil
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
