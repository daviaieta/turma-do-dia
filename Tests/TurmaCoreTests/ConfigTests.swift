import Foundation
import Testing
@testable import TurmaCore

@Suite("Config")
struct ConfigTests {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("turma-tests-\(UUID().uuidString)", isDirectory: true)

    private func write(_ json: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("reminders.json")
        try Data(json.utf8).write(to: url)
        return url
    }

    @Test func `carrega com valores padrão para o que falta`() throws {
        let url = try write("""
        { "reminders": [
            { "id": "agua", "character": "gota", "title": "Hora da", "word": "água!",
              "schedule": { "every": 120, "from": "09:00", "to": "19:00" } }
        ] }
        """)
        let config = try Config.load(from: url)
        #expect(config.cardSeconds == 90)
        #expect(config.snoozeMinutes == 10)
        #expect(config.reminders.count == 1)
        #expect(config.reminders[0].enabled)
        #expect(config.reminders[0].subtitle == "")
    }

    @Test func `json quebrado dá erro útil`() throws {
        let url = try write("{ \"reminders\": [ ")
        #expect {
            try Config.load(from: url)
        } throws: { error in
            guard case ConfigError.invalidJSON = error else { return false }
            return error.localizedDescription.contains("JSON")
        }
    }

    @Test func `campo que falta diz qual é e onde`() throws {
        let url = try write("""
        { "reminders": [ { "id": "agua", "character": "gota", "word": "água!", "schedule": { "at": ["09:00"] } } ] }
        """)
        #expect {
            try Config.load(from: url)
        } throws: { error in
            let message = error.localizedDescription
            return message.contains("title") && message.contains("reminders")
        }
    }

    @Test func `arquivo que não existe`() {
        let url = directory.appendingPathComponent("nao-existe.json")
        #expect {
            try Config.load(from: url)
        } throws: { error in
            guard case ConfigError.unreadable = error else { return false }
            return error.localizedDescription.contains("nao-existe.json")
        }
    }

    @Test func `carregar valida`() throws {
        let url = try write("""
        { "reminders": [ { "id": "agua", "character": "gota", "title": "a", "word": "b", "schedule": { "at": ["9:99"] } } ] }
        """)
        #expect(throws: ConfigError.invalidTime(reminder: "agua", value: "9:99")) { try Config.load(from: url) }
    }

    @Test func `defaults vão e voltam pelo arquivo sem mudar`() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("reminders.json")
        #expect(try Config.writeDefaultsIfMissing(to: url))
        #expect(try Config.load(from: url) == Config.defaults)
    }

    @Test func `arquivo gerado é legível e volta igual, até com aspas`() throws {
        var tricky = reminder("x", .every(30, from: "09:00", to: "10:00", days: ["seg"]))
        tricky.subtitle = #"Diz "oi" e \ barra / ok"#
        tricky.enabled = false
        let config = Config(reminders: [tricky, reminder("y", .at(["08:00"]))], cardSeconds: 30, snoozeMinutes: 5)
        let data = try config.encoded()
        #expect(try Config.decode(data) == config)

        let text = String(decoding: data, as: UTF8.self)
        let order = ["\"id\"", "\"character\"", "\"title\"", "\"word\"", "\"subtitle\"", "\"enabled\"", "\"schedule\""]
            .map { try! #require(text.range(of: $0)).lowerBound }
        #expect(order == order.sorted())
    }

    @Test func `nunca sobrescreve o arquivo do dono`() throws {
        let url = try write(#"{ "reminders": [] }"#)
        #expect(try Config.writeDefaultsIfMissing(to: url) == false)
        #expect(try Config.load(from: url).reminders.isEmpty)
    }
}

@Suite("Lembretes padrão")
struct DefaultsTests {
    @Test func `um lembrete para cada um dos 10 personagens`() {
        let characters = Config.defaults.reminders.map(\.character)
        #expect(Set(characters) == Set(CharacterID.allCases.map(\.rawValue)))
        #expect(characters.count == 10)
        #expect(CharacterID.allCases.map(\.rawValue) == [
            "sol", "mochila", "gota", "prato", "prompt", "gi", "peso", "lua", "claquete", "travesseiro",
        ])
    }

    @Test func `todos válidos`() throws {
        try Config.defaults.validate()
        #expect(Config.defaults.cardSeconds == 90)
        #expect(Config.defaults.snoozeMinutes == 10)
    }

    @Test func `horários pedidos`() throws {
        func schedule(_ character: String) throws -> Schedule {
            try #require(Config.defaults.reminders.first { $0.character == character }).schedule
        }
        let weekdays = ["seg", "ter", "qua", "qui", "sex"]
        #expect(try schedule("sol") == .at(["07:00"]))
        #expect(try schedule("mochila") == .at(["07:30"], days: weekdays))
        #expect(try schedule("gota") == .every(120, from: "09:00", to: "19:00"))
        #expect(try schedule("prato") == .at(["08:00", "12:30", "16:00", "19:30"]))
        #expect(try schedule("prompt") == .at(["14:00"], days: weekdays))
        #expect(try schedule("gi") == .at(["17:00"], days: ["seg", "qua", "sex"]))
        #expect(try schedule("peso") == .at(["17:00"], days: ["ter", "qui"]))
        #expect(try schedule("lua") == .at(["19:00"]))
        #expect(try schedule("claquete") == .at(["20:00"], days: ["ter"]))
        #expect(try schedule("travesseiro") == .at(["21:30"]))
    }

    @Test func `subtítulos pedidos`() throws {
        let prompt = try #require(Config.defaults.reminders.first { $0.character == "prompt" })
        #expect(prompt.subtitle == "Código na mão por 45 minutos. Um passo de cada vez.")
        let pillow = try #require(Config.defaults.reminders.first { $0.character == "travesseiro" })
        #expect(pillow.subtitle == "Telas fora. Amanhã tem o Sol te esperando.")
    }

    @Test func `sem dado pessoal nos textos`() throws {
        // Hora escrita no texto ("6h", "6h45"), escola e regra pessoal ficam de fora dos padrões.
        let forbidden = [#"\b\d{1,2}h(\d{2})?\b"#, #"(?i)escola"#, #"\bIA\b"#]
        for r in Config.defaults.reminders {
            for text in [r.id, r.title, r.word, r.subtitle] {
                for pattern in forbidden {
                    #expect(text.range(of: pattern, options: .regularExpression) == nil, "\(r.id): \"\(text)\" bate em \(pattern)")
                }
            }
        }
    }

    @Test func `todo texto preenchido`() {
        for r in Config.defaults.reminders {
            #expect(!r.title.isEmpty && !r.word.isEmpty && !r.subtitle.isEmpty, "\(r.id)")
        }
    }
}
