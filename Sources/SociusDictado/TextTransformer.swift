import Foundation

/// Optional post-processing of a transcript with an LLM before pasting.
enum AIMode: String, CaseIterable, Identifiable {
    case none, clean, bullets, email, translateEN

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:        return "Ninguno (texto tal cual)"
        case .clean:       return "Limpiar y puntuar"
        case .bullets:     return "Convertir en bullets"
        case .email:       return "Redactar como correo"
        case .translateEN: return "Traducir a inglés"
        }
    }

    var systemPrompt: String? {
        switch self {
        case .none:
            return nil
        case .clean:
            return "Eres un editor. Corrige puntuación, mayúsculas y errores obvios del dictado, sin cambiar el significado ni el idioma. Devuelve SOLO el texto corregido, sin comillas ni comentarios."
        case .bullets:
            return "Convierte el dictado en una lista de bullets claros y concisos, conservando el idioma original. Devuelve SOLO los bullets (uno por línea con '- '), sin encabezados."
        case .email:
            return "Reescribe el dictado como un correo profesional y cordial en el mismo idioma. Mantén el fondo del mensaje. Devuelve SOLO el cuerpo del correo, sin asunto ni firma."
        case .translateEN:
            return "Translate the dictation into natural English. Return ONLY the translation, no quotes or notes."
        }
    }
}

enum TextTransformer {
    /// Returns the transformed text, or the original if the mode is none/empty or it fails.
    static func apply(_ mode: AIMode, to text: String) async -> String {
        guard let system = mode.systemPrompt, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let key = Keychain.get(), !key.isEmpty else { return text }

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": text],
            ],
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return text }
        req.httpBody = body

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any],
                  let content = msg["content"] as? String else { return text }
            let out = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return out.isEmpty ? text : out
        } catch {
            return text   // never block the paste on an AI failure
        }
    }
}
