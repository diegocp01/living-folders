import Foundation

/// Sends one `noul` question per file to Jev (`jev-latest`) and maps the answers to memberships.
/// Mirrors the payload of the original Python proxy. Requires `TYPESAFE_API_KEY`.
public struct JevClassifier: Sendable {
    public static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    public static let maxDocuments = 40
    public static let threshold = 0.55

    public let apiKey: String

    public init(apiKey: String) { self.apiKey = apiKey }

    public static func resolveKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !key.isEmpty { return key }
        if let key = UserDefaults.standard.string(forKey: "TYPESAFE_API_KEY"), !key.isEmpty { return key }
        return nil
    }

    public func classify(folderName: String, items: [FileItem]) async throws -> [Membership] {
        let batch = Array(items.prefix(Self.maxDocuments))
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.payload(folderName: folderName, items: batch))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw JevError.unavailable }
        if http.statusCode == 401 || http.statusCode == 403 { throw JevError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw JevError.unavailable }
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try Self.parse(items: batch, result: result)
    }

    static func payload(folderName: String, items: [FileItem]) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        let state: [String: Any] = [
            "virtual_folder": folderName,
            "documents": items.map { item in
                ["id": item.id, "name": item.name, "kind": item.isDirectory ? "folder" : item.ext.uppercased(), "modified": formatter.string(from: item.modified), "size": item.size]
            },
        ]
        var questions: [String: Any] = [:]
        for item in items {
            questions[item.id] = [
                "type": "noul",
                "instructions": "The virtual folder is named: '\(folderName)'. Would the file '\(item.name)' meaningfully belong in that collection? Use the filename, kind, modification date, and ordinary user intent. Be selective: related is not enough; it should be useful for the named purpose.",
            ]
        }
        let stateJSON = String(data: try! JSONSerialization.data(withJSONObject: state), encoding: .utf8)!
        return ["model": "jev-latest", "state": stateJSON, "questions": questions]
    }

    static func parse(items: [FileItem], result: [String: Any]) throws -> [Membership] {
        let answers = result["answers"] as? [String: Any] ?? [:]
        return try items.map { item in
            guard let answer = answers[item.id] as? [String: Any], let score = answer["noul"] as? Double, (0...1).contains(score) else {
                throw JevError.invalidAnswer(item.name)
            }
            return Membership(id: item.id, belongs: score >= threshold, confidence: (score * 1000).rounded() / 1000)
        }
    }
}

public enum JevError: LocalizedError {
    case unauthorized, unavailable, invalidAnswer(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Jev authentication failed. Check your API key."
        case .unavailable: return "Jev is unavailable right now."
        case .invalidAnswer(let name): return "Jev returned an invalid answer for \(name)."
        }
    }
}
