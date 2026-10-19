import Foundation
import TurmaCore

/// Flags de linha de comando, para desenvolvimento e teste.
///   --config <arquivo>     arquivo de horários (padrão: <state-dir>/reminders.json)
///   --state-dir <pasta>    onde ficam reminders.json e historico.json
///   --show <personagem>    mostra um cartão de teste ao abrir
///   --slow                 animações em câmera lenta
struct LaunchOptions {
    var stateDirectory: URL
    var configURL: URL
    var showCharacter: CharacterID?
    var slow = false

    static var defaultStateDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Turma", isDirectory: true)
    }

    struct ParseError: Error, CustomStringConvertible {
        let description: String
    }

    static func parse(_ arguments: [String]) throws -> LaunchOptions {
        var stateDirectory: URL?
        var configURL: URL?
        var show: CharacterID?
        var slow = false

        var rest = arguments[...]
        func value(for flag: String) throws -> String {
            guard let next = rest.popFirst(), !next.hasPrefix("--") else {
                throw ParseError(description: "\(flag) precisa de um valor.")
            }
            return next
        }

        while let argument = rest.popFirst() {
            switch argument {
            case "--config":
                configURL = URL(fileURLWithPath: try value(for: argument)).standardizedFileURL
            case "--state-dir":
                stateDirectory = URL(fileURLWithPath: try value(for: argument), isDirectory: true).standardizedFileURL
            case "--show":
                let id = try value(for: argument)
                guard let character = CharacterID(rawValue: id) else {
                    let known = CharacterID.allCases.map(\.rawValue).joined(separator: ", ")
                    throw ParseError(description: "--show: personagem desconhecido \"\(id)\". Use: \(known).")
                }
                show = character
            case "--slow":
                slow = true
            default:
                // O macOS e o Xcode às vezes passam argumentos próprios (ex.: -NSDocumentRevisionsDebugMode). Ignora.
                FileHandle.standardError.write(Data("Turma: ignorando argumento \(argument)\n".utf8))
            }
        }

        let directory = stateDirectory ?? defaultStateDirectory
        return LaunchOptions(
            stateDirectory: directory,
            configURL: configURL ?? directory.appendingPathComponent("reminders.json"),
            showCharacter: show,
            slow: slow
        )
    }
}
