import Foundation
import Testing
@testable import TurmaCore

@Suite("Agendador")
struct SchedulerTests {
    @Test func `dispara na hora e não antes`() {
        let h = Harness([reminder("agua", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.go("2026-10-19 09:59:59")
        #expect(h.fired.isEmpty)
        h.go("2026-10-19 10:00")
        #expect(h.fired == ["agua"])
        #expect(h.scheduler.showing?.id == "agua")
    }

    @Test func `não dispara duas vezes o mesmo horário`() {
        let h = Harness([reminder("agua", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.go("2026-10-19 10:00")
        h.scheduler.cardClosed()
        h.go("2026-10-19 10:00:30")
        h.go("2026-10-19 10:05")
        #expect(h.fired == ["agua"])
    }

    @Test func `próximo entre todos os lembretes`() throws {
        let h = Harness([
            reminder("a", .at(["12:00"])),
            reminder("b", .at(["10:30"])),
            reminder("c", .at(["09:00"]), enabled: false),
        ], at: "2026-10-19 08:00")
        let next = try #require(h.scheduler.next())
        #expect(next.reminder.id == "b")
        #expect(next.date == date("2026-10-19 10:30"))
    }

    @Test func `lembrete desligado nunca dispara`() {
        let h = Harness([reminder("a", .at(["09:00"]), enabled: false)], at: "2026-10-19 08:00")
        h.go("2026-10-19 09:00")
        #expect(h.fired.isEmpty)
        #expect(h.scheduler.next() == nil)
    }

    @Test func `adiar dispara de novo depois de N minutos`() {
        let h = Harness([reminder("agua", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.go("2026-10-19 10:00")
        h.scheduler.snooze("agua", minutes: 10)
        h.scheduler.cardClosed()
        #expect(h.scheduler.next()?.date == date("2026-10-19 10:10"))
        h.go("2026-10-19 10:09")
        #expect(h.fired == ["agua"])
        h.go("2026-10-19 10:10")
        #expect(h.fired == ["agua", "agua"])
        // Depois do adiado, volta ao horário normal.
        h.scheduler.cardClosed()
        #expect(h.scheduler.next()?.date == date("2026-10-20 10:00"))
    }

    @Test func `adiar não apaga o horário normal que vem antes`() {
        // Gota a cada 15 min; adiar por 20 não pode engolir o disparo das 10:15.
        let h = Harness([reminder("agua", .every(15, from: "10:00", to: "11:00"))], at: "2026-10-19 09:00")
        h.go("2026-10-19 10:00")
        h.scheduler.snooze("agua", minutes: 20)
        h.scheduler.cardClosed()
        h.go("2026-10-19 10:15")
        #expect(h.fired == ["agua", "agua"])
    }

    @Test func `pausar uma hora segura tudo e volta sozinho`() {
        let h = Harness([reminder("a", .every(30, from: "09:00", to: "12:00"))], at: "2026-10-19 09:10")
        h.scheduler.pauseOneHour()
        #expect(h.scheduler.isPaused)
        #expect(h.scheduler.pausedUntil == date("2026-10-19 10:10"))
        h.go("2026-10-19 09:30")
        h.go("2026-10-19 10:00")
        #expect(h.fired.isEmpty)
        #expect(h.scheduler.next()?.date == date("2026-10-19 10:30"))
        h.go("2026-10-19 10:30")
        #expect(h.fired == ["a"])
        #expect(!h.scheduler.isPaused)
    }

    @Test func `pausar até amanhã às seis`() {
        let h = Harness([reminder("a", .at(["06:00", "22:00"]))], at: "2026-10-19 21:00")
        h.scheduler.pauseUntilTomorrowMorning()
        #expect(h.scheduler.pausedUntil == date("2026-10-20 06:00"))
        h.go("2026-10-19 22:00")
        #expect(h.fired.isEmpty)
        // O das 06:00 em ponto já vale: a pausa terminou.
        h.go("2026-10-20 06:00")
        #expect(h.fired == ["a"])
    }

    @Test func `retomar volta a disparar na hora`() {
        let h = Harness([reminder("a", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.scheduler.pauseOneHour()
        h.scheduler.resume()
        #expect(!h.scheduler.isPaused)
        h.go("2026-10-19 10:00")
        #expect(h.fired == ["a"])
    }

    @Test func `pausar descarta adiados e a fila`() {
        let h = Harness([
            reminder("a", .at(["10:00"])),
            reminder("b", .at(["10:00"])),
        ], at: "2026-10-19 09:00")
        h.go("2026-10-19 10:00")
        #expect(h.scheduler.queue.map(\.id) == ["b"])
        h.scheduler.snooze("a", minutes: 10)
        h.scheduler.pauseOneHour()
        h.scheduler.cardClosed()
        h.go("2026-10-19 10:10")
        #expect(h.fired == ["a"])
        #expect(h.scheduler.queue.isEmpty)
    }

    @Test func `ao acordar descarta o que passou de 15 minutos`() {
        let h = Harness([reminder("sol", .at(["07:00"]))], at: "2026-10-19 06:00")
        // O Mac dormiu às 06:50 e acordou às 07:20: o timer não rodou.
        h.clock.set("2026-10-19 07:20")
        h.scheduler.didWake()
        #expect(h.fired.isEmpty)
        #expect(h.scheduler.next()?.date == date("2026-10-20 07:00"))
    }

    @Test func `ao acordar dispara o que atrasou até 15 minutos`() {
        let h = Harness([reminder("sol", .at(["07:00"]))], at: "2026-10-19 06:00")
        h.clock.set("2026-10-19 07:15")
        h.scheduler.didWake()
        #expect(h.fired == ["sol"])
    }

    @Test func `sono longo não despeja vários disparos de uma vez`() {
        let h = Harness([reminder("agua", .every(60, from: "09:00", to: "19:00"))], at: "2026-10-19 08:00")
        h.clock.set("2026-10-19 13:05")
        h.scheduler.didWake()
        #expect(h.fired.isEmpty)
        #expect(h.scheduler.next()?.date == date("2026-10-19 14:00"))
    }

    @Test func `adiado vencido há muito tempo também é descartado`() {
        let h = Harness([reminder("a", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.go("2026-10-19 10:00")
        h.scheduler.snooze("a", minutes: 10)
        h.scheduler.cardClosed()
        h.clock.set("2026-10-19 11:00")
        h.scheduler.didWake()
        #expect(h.fired == ["a"])
    }

    @Test func `simultâneos entram um por vez, na ordem do arquivo`() {
        let h = Harness([
            reminder("a", .at(["10:00"])),
            reminder("b", .at(["10:00"])),
            reminder("c", .at(["09:00"])),
        ], at: "2026-10-19 08:00")
        h.go("2026-10-19 09:00")
        #expect(h.fired == ["c"])
        h.go("2026-10-19 10:00")  // c ainda na tela
        #expect(h.fired == ["c"])
        #expect(h.scheduler.queue.map(\.id) == ["a", "b"])
        h.scheduler.cardClosed()
        #expect(h.fired == ["c", "a"])
        h.scheduler.cardClosed()
        #expect(h.fired == ["c", "a", "b"])
        h.scheduler.cardClosed()
        #expect(h.fired == ["c", "a", "b"])
        #expect(h.scheduler.showing == nil)
    }

    @Test func `quem venceu antes passa na frente`() {
        let h = Harness([
            reminder("tarde", .at(["10:05"])),
            reminder("cedo", .at(["10:00"])),
        ], at: "2026-10-19 09:00")
        h.clock.set("2026-10-19 10:06")
        h.scheduler.tick()
        h.scheduler.cardClosed()
        #expect(h.fired == ["cedo", "tarde"])
    }

    @Test func `testar mostra na hora, mesmo pausado, e entra na fila se houver cartão`() {
        let r = reminder("x", .at(["23:00"]))
        let h = Harness([reminder("a", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.scheduler.pauseOneHour()
        h.scheduler.trigger(r)
        #expect(h.fired == ["x"])
        h.scheduler.trigger(reminder("y", .at(["23:00"])))
        #expect(h.fired == ["x"])
        h.scheduler.cardClosed()
        #expect(h.fired == ["x", "y"])
    }

    @Test func `recarregar a config recalcula`() {
        let h = Harness([reminder("a", .at(["10:00"]))], at: "2026-10-19 09:00")
        h.scheduler.reload(Config(reminders: [reminder("a", .at(["09:30"])), reminder("b", .at(["09:15"]))]))
        #expect(h.scheduler.next()?.reminder.id == "b")
        h.go("2026-10-19 09:15")
        h.scheduler.cardClosed()
        h.go("2026-10-19 09:30")
        #expect(h.fired == ["b", "a"])
        h.scheduler.cardClosed()
        h.go("2026-10-19 10:00")
        #expect(h.fired == ["b", "a"])
    }

    @Test func `recarregar tira da fila e dos adiados o que saiu`() {
        let h = Harness([
            reminder("a", .at(["10:00"])),
            reminder("b", .at(["10:00"])),
        ], at: "2026-10-19 09:00")
        h.go("2026-10-19 10:00")
        h.scheduler.reload(Config(reminders: [reminder("a", .at(["10:00"]))]))
        h.scheduler.snooze("a", minutes: 5)
        h.scheduler.reload(Config(reminders: [reminder("a", .at(["10:00"]), enabled: false)]))
        h.scheduler.cardClosed()
        h.go("2026-10-19 10:05")
        #expect(h.fired == ["a"])
        #expect(h.scheduler.next() == nil)
    }

    @Test func `recarregar mantém a pausa`() {
        let h = Harness([reminder("a", .at(["09:30"]))], at: "2026-10-19 09:00")
        h.scheduler.pauseOneHour()
        h.scheduler.reload(Config(reminders: [reminder("a", .at(["09:45"]))]))
        #expect(h.scheduler.isPaused)
        h.go("2026-10-19 09:45")
        #expect(h.fired.isEmpty)
    }

    @Test func `quando acordar o timer`() {
        let h = Harness([reminder("a", .at(["10:00"]))], at: "2026-10-19 09:00")
        #expect(h.scheduler.nextWakeDate() == date("2026-10-19 10:00"))
        h.scheduler.pauseOneHour()
        // Durante a pausa, o timer precisa acordar no fim dela.
        #expect(h.scheduler.nextWakeDate() == date("2026-10-19 10:00"))
    }
}
