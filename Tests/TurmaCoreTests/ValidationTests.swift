import Foundation
import Testing
@testable import TurmaCore

@Suite("Validação")
struct ValidationTests {
    @Test func `lembrete válido passa`() throws {
        try reminder("a", .at(["06:00", "13:30"])).validate()
        try reminder("b", .every(120, from: "09:00", to: "19:00", days: ["seg", "sex"])).validate()
    }

    @Test(arguments: ["25:00", "12:60", "7h", "", "ab:cd", "12:5", "-1:00", "12:00:00"])
    func `hora inválida`(value: String) {
        #expect(throws: ConfigError.invalidTime(reminder: "a", value: value)) {
            try reminder("a", .at([value])).validate()
        }
    }

    @Test func `hora inválida na janela do every`() {
        #expect(throws: ConfigError.invalidTime(reminder: "a", value: "9h")) {
            try reminder("a", .every(60, from: "9h", to: "19:00")).validate()
        }
    }

    @Test func `dia inválido`() {
        #expect(throws: ConfigError.invalidDay(reminder: "a", value: "segunda")) {
            try reminder("a", .at(["06:00"], days: ["seg", "segunda"])).validate()
        }
    }

    @Test func `personagem desconhecido`() {
        #expect(throws: ConfigError.unknownCharacter(reminder: "a", value: "dragao")) {
            try reminder("a", character: "dragao", .at(["06:00"])).validate()
        }
    }

    @Test(arguments: [0, -30])
    func `every menor ou igual a zero`(minutes: Int) {
        #expect(throws: ConfigError.nonPositiveEvery(reminder: "a", value: minutes)) {
            try reminder("a", .every(minutes, from: "09:00", to: "10:00")).validate()
        }
    }

    @Test func `janela invertida`() {
        #expect(throws: ConfigError.invertedWindow(reminder: "a", from: "19:00", to: "09:00")) {
            try reminder("a", .every(60, from: "19:00", to: "09:00")).validate()
        }
    }

    @Test func `nem at nem every`() {
        #expect(throws: ConfigError.missingSchedule(reminder: "a")) {
            try reminder("a", Schedule()).validate()
        }
        #expect(throws: ConfigError.missingSchedule(reminder: "a")) {
            try reminder("a", .at([])).validate()
        }
    }

    @Test func `at e every juntos`() {
        let schedule = Schedule(at: ["06:00"], every: 60, from: "09:00", to: "10:00")
        #expect(throws: ConfigError.bothAtAndEvery(reminder: "a")) {
            try reminder("a", schedule).validate()
        }
    }

    @Test func `every sem janela`() {
        #expect(throws: ConfigError.missingWindow(reminder: "a")) {
            try reminder("a", Schedule(every: 60)).validate()
        }
    }

    @Test func `id repetido na config`() {
        let config = Config(reminders: [reminder("a", .at(["06:00"])), reminder("a", .at(["07:00"]))])
        #expect(throws: ConfigError.duplicateID("a")) { try config.validate() }
    }

    @Test func `números da config precisam ser positivos`() {
        #expect(throws: ConfigError.invalidNumber(field: "cardSeconds", value: 0)) {
            try Config(reminders: [], cardSeconds: 0).validate()
        }
        #expect(throws: ConfigError.invalidNumber(field: "snoozeMinutes", value: -5)) {
            try Config(reminders: [], snoozeMinutes: -5).validate()
        }
    }

    @Test func `mensagens de erro em português e com o id do lembrete`() {
        let error = ConfigError.invalidDay(reminder: "agua", value: "monday")
        let message = error.localizedDescription
        #expect(message.contains("agua"))
        #expect(message.contains("monday"))
        #expect(message.contains("dia"))
    }
}
