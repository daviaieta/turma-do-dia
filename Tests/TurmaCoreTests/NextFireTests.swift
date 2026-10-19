import Foundation
import Testing
@testable import TurmaCore

@Suite("Próximo disparo")
struct NextFireTests {
    @Test func `19 de outubro de 2026 é segunda`() {
        #expect(testCalendar.component(.weekday, from: date("2026-10-19 12:00")) == 2)
    }

    @Test func `próximo horário do mesmo dia`() {
        let r = reminder("a", .at(["06:00", "13:30"]))
        #expect(r.nextFire(after: date("2026-10-19 08:00"), calendar: testCalendar) == date("2026-10-19 13:30"))
    }

    @Test func `horários fora de ordem no arquivo`() {
        let r = reminder("a", .at(["19:30", "08:00", "12:30"]))
        #expect(r.nextFire(after: date("2026-10-19 07:00"), calendar: testCalendar) == date("2026-10-19 08:00"))
    }

    @Test func `vira o dia quando já passou o último horário`() {
        let r = reminder("a", .at(["06:00", "13:30"]))
        #expect(r.nextFire(after: date("2026-10-19 14:00"), calendar: testCalendar) == date("2026-10-20 06:00"))
    }

    @Test func `hora exatamente igual a after vai para a próxima`() {
        let r = reminder("a", .at(["06:00", "13:30"]))
        #expect(r.nextFire(after: date("2026-10-19 06:00"), calendar: testCalendar) == date("2026-10-19 13:30"))
        #expect(r.nextFire(after: date("2026-10-19 05:59:59"), calendar: testCalendar) == date("2026-10-19 06:00"))
    }

    @Test func `filtro de dias pula o fim de semana`() {
        // Sexta 23/out depois do horário: o próximo dia útil é segunda 26/out.
        let r = reminder("a", .at(["07:30"], days: ["seg", "ter", "qua", "qui", "sex"]))
        #expect(r.nextFire(after: date("2026-10-23 08:00"), calendar: testCalendar) == date("2026-10-26 07:30"))
    }

    @Test func `um dia por semana espera a semana inteira`() {
        // Terça 20/out depois das 20:00: só na terça seguinte.
        let r = reminder("a", .at(["20:00"], days: ["ter"]))
        #expect(r.nextFire(after: date("2026-10-20 20:00"), calendar: testCalendar) == date("2026-10-27 20:00"))
    }

    @Test func `domingo e sábado`() {
        let r = reminder("a", .at(["10:00"], days: ["dom"]))
        #expect(r.nextFire(after: date("2026-10-19 10:00"), calendar: testCalendar) == date("2026-10-25 10:00"))
        let s = reminder("b", .at(["10:00"], days: ["sab"]))
        #expect(s.nextFire(after: date("2026-10-19 10:00"), calendar: testCalendar) == date("2026-10-24 10:00"))
    }

    @Test func `every ancora em from`() {
        let r = reminder("a", .every(120, from: "09:00", to: "19:00"))
        #expect(r.nextFire(after: date("2026-10-19 06:00"), calendar: testCalendar) == date("2026-10-19 09:00"))
        #expect(r.nextFire(after: date("2026-10-19 09:00"), calendar: testCalendar) == date("2026-10-19 11:00"))
        #expect(r.nextFire(after: date("2026-10-19 10:17"), calendar: testCalendar) == date("2026-10-19 11:00"))
    }

    @Test func `every respeita o fim da janela, inclusive`() {
        let r = reminder("a", .every(120, from: "09:00", to: "19:00"))
        #expect(r.nextFire(after: date("2026-10-19 17:30"), calendar: testCalendar) == date("2026-10-19 19:00"))
        #expect(r.nextFire(after: date("2026-10-19 19:00"), calendar: testCalendar) == date("2026-10-20 09:00"))
    }

    @Test func `every que não cabe certinho na janela`() {
        // 09:00, 10:30 ... 18:00; 19:30 passa do fim.
        let r = reminder("a", .every(90, from: "09:00", to: "19:00"))
        #expect(r.nextFire(after: date("2026-10-19 18:00"), calendar: testCalendar) == date("2026-10-20 09:00"))
    }

    @Test func `every com filtro de dias`() {
        let r = reminder("a", .every(60, from: "09:00", to: "10:00", days: ["qua"]))
        #expect(r.nextFire(after: date("2026-10-19 08:00"), calendar: testCalendar) == date("2026-10-21 09:00"))
    }

    @Test func `borda 23:59 para 00:00`() {
        let r = reminder("a", .at(["00:00", "23:59"]))
        #expect(r.nextFire(after: date("2026-10-19 23:58"), calendar: testCalendar) == date("2026-10-19 23:59"))
        #expect(r.nextFire(after: date("2026-10-19 23:59"), calendar: testCalendar) == date("2026-10-20 00:00"))
        #expect(r.nextFire(after: date("2026-10-19 23:59:30"), calendar: testCalendar) == date("2026-10-20 00:00"))
    }

    @Test func `virada de mês e de ano`() {
        let r = reminder("a", .at(["07:00"]))
        #expect(r.nextFire(after: date("2026-10-31 08:00"), calendar: testCalendar) == date("2026-11-01 07:00"))
        #expect(r.nextFire(after: date("2026-12-31 08:00"), calendar: testCalendar) == date("2027-01-01 07:00"))
    }

    @Test func `lembrete inválido não tem próximo disparo`() {
        #expect(reminder("a", .at(["99:00"])).nextFire(after: date("2026-10-19 08:00"), calendar: testCalendar) == nil)
        #expect(reminder("a", Schedule()).nextFire(after: date("2026-10-19 08:00"), calendar: testCalendar) == nil)
    }
}
