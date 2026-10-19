import AppKit
import os
import TurmaCore
import WebKit

private let log = Logger(subsystem: "br.com.daviaieta.turma", category: "card")

/// Painel sem borda, que flutua em todos os Spaces e sobre apps em tela cheia sem roubar o foco.
final class CardPanel: NSPanel {
    var onEscape: (() -> Void)?

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // a sombra vem do CSS do cartão
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        // Só vira janela-chave quando alguém clica nele: um cartão aparecendo não engole o que a pessoa está digitando.
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// Um cartão na tela: carrega `web/card.html`, conversa com a página e avisa o resultado uma vez só.
final class CardController: NSObject, WKScriptMessageHandler {
    enum Result {
        case done, snoozed, ignored, dismissed
    }

    static let size = NSSize(width: 420, height: 140)
    static let margin: CGFloat = 16

    let reminder: Reminder
    private let cardSeconds: Int
    private let snoozeMinutes: Int
    private let slow: Bool
    /// A pessoa decidiu (ou o tempo acabou). Chamado uma vez.
    private let onResult: (Result) -> Void
    /// O painel sumiu. Chamado uma vez, sempre depois de `onResult`.
    private let onClosed: () -> Void

    private let panel: CardPanel
    private let webView: WKWebView
    private var timer: Timer?
    private var resolved = false
    private var closed = false

    private var slowFactor: Double { slow ? 3 : 1 }

    init(
        reminder: Reminder, cardSeconds: Int, snoozeMinutes: Int, slow: Bool,
        onResult: @escaping (Result) -> Void, onClosed: @escaping () -> Void
    ) {
        self.reminder = reminder
        self.cardSeconds = cardSeconds
        self.snoozeMinutes = snoozeMinutes
        self.slow = slow
        self.onResult = onResult
        self.onClosed = onClosed

        panel = CardPanel(frame: Self.frameOnMainScreen())
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(origin: .zero, size: Self.size), configuration: configuration)
        super.init()

        // O WKUserContentController segura o handler com referência forte; `close()` remove para não vazar.
        configuration.userContentController.add(self, name: "turma")
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        webView.autoresizingMask = [.width, .height]
        panel.contentView = webView
        panel.onEscape = { [weak self] in self?.resolve(.dismissed) }
    }

    /// Tela principal (a da barra de menu), canto superior direito, abaixo da barra.
    private static func frameOnMainScreen() -> NSRect {
        guard let screen = NSScreen.screens.first else { return NSRect(origin: .zero, size: size) }
        let area = screen.visibleFrame
        return NSRect(
            x: area.maxX - size.width - margin,
            y: area.maxY - size.height - margin,
            width: size.width, height: size.height)
    }

    func open() {
        guard let page = Bundle.module.url(forResource: "card", withExtension: "html", subdirectory: "web") else {
            log.error("web/card.html não está no bundle de recursos")
            resolve(.dismissed)
            return
        }
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        // Se a página nunca disser "ready", não deixa a fila travada.
        startTimer(seconds: 10) { [weak self] in
            log.error("card.html não respondeu ready")
            self?.resolve(.dismissed)
        }
    }

    // MARK: - JS -> Swift

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        switch action {
        case "ready": show()
        case "done": celebrate()
        case "snooze": resolve(.snoozed)
        case "dismiss": resolve(.dismissed)
        case "finished": close()
        default: log.debug("ação desconhecida da página: \(action, privacy: .public)")
        }
    }

    // MARK: - Swift -> JS

    private struct ShowPayload: Encodable {
        let character, title, word, subtitle: String
        let snoozeMinutes: Int
        let slow: Bool
    }

    private func show() {
        guard !resolved else { return }
        let payload = ShowPayload(
            character: reminder.character, title: reminder.title, word: reminder.word,
            subtitle: reminder.subtitle, snoozeMinutes: snoozeMinutes, slow: slow)
        guard let data = try? JSONEncoder().encode(payload), let json = String(data: data, encoding: .utf8) else { return }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        webView.evaluateJavaScript("window.turma.show(\(json))")
        startTimer(seconds: TimeInterval(cardSeconds)) { [weak self] in self?.resolve(.ignored) }
    }

    private func celebrate() {
        guard !resolved else { return }
        resolved = true
        onResult(.done)
        webView.evaluateJavaScript("window.turma.celebrate()")
        // A página manda "finished" em ~1,8 s; se não mandar, fecha mesmo assim.
        startTimer(seconds: 1.8 * slowFactor + 2) { [weak self] in self?.close() }
    }

    // MARK: - Fim

    private func resolve(_ result: Result) {
        guard !resolved else { return }
        resolved = true
        onResult(result)
        close()
    }

    private func close() {
        guard !closed else { return }
        closed = true
        timer?.invalidate()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "turma")

        let finish: @MainActor () -> Void = { [panel, onClosed] in
            panel.orderOut(nil)
            onClosed()
        }
        if !panel.isVisible || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 * slowFactor
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { finish() }
        })
    }

    private func startTimer(seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
    }
}
