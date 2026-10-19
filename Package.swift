// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "turma-do-dia",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Turma", targets: ["Turma"]),
        .library(name: "TurmaCore", targets: ["TurmaCore"]),
    ],
    targets: [
        // Regras e horários, sem UI. Biblioteca: não fica presa ao main actor.
        .target(name: "TurmaCore"),
        // O app de barra de menu. AppKit e WebKit vivem no main actor, então ele é o padrão.
        .executableTarget(
            name: "Turma",
            dependencies: ["TurmaCore"],
            resources: [.copy("Resources/web")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "TurmaCoreTests", dependencies: ["TurmaCore"]),
    ]
)
