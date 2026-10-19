/// Os 10 personagens. O `rawValue` é o id usado no JSON e no front-end web.
public enum CharacterID: String, CaseIterable, Sendable {
    case sol, mochila, gota, prato, prompt, gi, peso, lua, claquete, travesseiro

    /// Nome para mostrar no menu.
    public var displayName: String {
        switch self {
        case .sol: "Sol"
        case .mochila: "Mochila"
        case .gota: "Gota"
        case .prato: "Prato"
        case .prompt: "Prompt"
        case .gi: "Gi"
        case .peso: "Peso"
        case .lua: "Lua"
        case .claquete: "Claquete"
        case .travesseiro: "Travesseiro"
        }
    }
}
