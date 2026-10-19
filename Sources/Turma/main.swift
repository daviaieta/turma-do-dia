import AppKit

let options: LaunchOptions
do {
    options = try LaunchOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("Turma: \(error)\n".utf8))
    exit(2)
}

let app = NSApplication.shared
// Sem ícone no Dock mesmo rodando fora do .app (no .app, o Info.plist já diz LSUIElement).
app.setActivationPolicy(.accessory)
let controller = AppController(options: options)
app.delegate = controller
app.run()
