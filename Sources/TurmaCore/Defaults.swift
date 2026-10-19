extension Config {
    /// Arquivo inicial: um lembrete por personagem, com textos genéricos.
    /// São propostas; o dono ajusta no `reminders.json`.
    public static let defaults = Config(reminders: [
        Reminder(
            id: "acordar", character: "sol", title: "Hora do", word: "sol!",
            subtitle: "Levanta e pega 10 minutos de luz na cara.",
            schedule: .at(["07:00"])),
        Reminder(
            id: "mochila", character: "mochila", title: "Hora da", word: "mochila!",
            subtitle: "Carregador, garrafa e o lanche. O lanche vai junto.",
            schedule: .at(["07:30"], days: weekdays)),
        Reminder(
            id: "agua", character: "gota", title: "Hora da", word: "água!",
            subtitle: "Um copo agora, antes de esquecer.",
            schedule: .every(120, from: "09:00", to: "19:00")),
        Reminder(
            id: "comer", character: "prato", title: "Hora de", word: "comer!",
            subtitle: "Prato de verdade, sem pular refeição.",
            schedule: .at(["08:00", "12:30", "16:00", "19:30"])),
        Reminder(
            id: "codigo", character: "prompt", title: "Hora do", word: "código!",
            subtitle: "Código na mão por 45 minutos. Um passo de cada vez.",
            schedule: .at(["14:00"], days: weekdays)),
        Reminder(
            id: "jiu", character: "gi", title: "Hora do", word: "jiu!",
            subtitle: "Kimono e garrafa na mochila. Banho logo depois.",
            schedule: .at(["17:00"], days: ["seg", "qua", "sex"])),
        Reminder(
            id: "academia", character: "peso", title: "Hora da", word: "academia!",
            subtitle: "Aquece primeiro. Hoje é dia de força.",
            schedule: .at(["17:00"], days: ["ter", "qui"])),
        Reminder(
            id: "oculos", character: "lua", title: "Hora do", word: "óculos!",
            subtitle: "Óculos laranja e a tela com o brilho lá embaixo.",
            schedule: .at(["19:00"])),
        Reminder(
            id: "marca", character: "claquete", title: "Hora da", word: "marca!",
            subtitle: "Um passo só: gravar, editar ou agendar.",
            schedule: .at(["20:00"], days: ["ter"])),
        Reminder(
            id: "dormir", character: "travesseiro", title: "Hora de", word: "dormir!",
            subtitle: "Telas fora. Amanhã tem o Sol te esperando.",
            schedule: .at(["21:30"])),
    ])

    private static let weekdays = ["seg", "ter", "qua", "qui", "sex"]
}
