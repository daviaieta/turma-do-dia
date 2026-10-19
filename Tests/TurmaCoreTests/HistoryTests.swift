import Foundation
import Testing
@testable import TurmaCore

@Suite("Histórico")
struct HistoryTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("turma-tests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func `conta por dia`() throws {
        let history = History(directory: directory)
        try history.record(.done, at: date("2026-10-19 07:00"), calendar: testCalendar)
        try history.record(.done, at: date("2026-10-19 12:00"), calendar: testCalendar)
        try history.record(.snoozed, at: date("2026-10-19 13:00"), calendar: testCalendar)
        try history.record(.ignored, at: date("2026-10-19 23:59"), calendar: testCalendar)
        try history.record(.done, at: date("2026-10-20 00:00"), calendar: testCalendar)

        let today = history.todayCounts(now: date("2026-10-19 23:59:59"), calendar: testCalendar)
        #expect(today == DayCounts(done: 2, snoozed: 1, ignored: 1))
        let tomorrow = history.todayCounts(now: date("2026-10-20 09:00"), calendar: testCalendar)
        #expect(tomorrow == DayCounts(done: 1, snoozed: 0, ignored: 0))
        #expect(history.todayCounts(now: date("2026-10-21 09:00"), calendar: testCalendar) == DayCounts())
    }

    @Test func `grava em arquivo e lê de volta`() throws {
        let history = History(directory: directory)
        try history.record(.done, at: date("2026-10-19 07:00"), calendar: testCalendar)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("historico.json").path))

        let reopened = History(directory: directory)
        #expect(reopened.todayCounts(now: date("2026-10-19 08:00"), calendar: testCalendar).done == 1)
        #expect(reopened.loadProblem == nil)
    }

    @Test func `arquivo corrompido não derruba e é guardado de lado`() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("historico.json")
        try Data("{ isto não é json".utf8).write(to: file)

        let history = History(directory: directory)
        #expect(history.loadProblem != nil)
        #expect(history.todayCounts(now: date("2026-10-19 08:00"), calendar: testCalendar) == DayCounts())

        try history.record(.done, at: date("2026-10-19 08:00"), calendar: testCalendar)
        let reopened = History(directory: directory)
        #expect(reopened.loadProblem == nil)
        #expect(reopened.todayCounts(now: date("2026-10-19 09:00"), calendar: testCalendar).done == 1)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("historico.corrompido.json").path))
    }

    @Test func `pasta que não existe é criada`() throws {
        let nested = directory.appendingPathComponent("a/b", isDirectory: true)
        let history = History(directory: nested)
        try history.record(.ignored, at: date("2026-10-19 08:00"), calendar: testCalendar)
        #expect(FileManager.default.fileExists(atPath: nested.appendingPathComponent("historico.json").path))
    }

    @Test func `formato do arquivo usa as palavras em português`() throws {
        let history = History(directory: directory)
        try history.record(.snoozed, at: date("2026-10-19 08:00"), calendar: testCalendar)
        let text = try String(contentsOf: history.fileURL, encoding: .utf8)
        #expect(text.contains("2026-10-19"))
        #expect(text.contains("adiado"))
    }
}
