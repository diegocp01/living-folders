import Foundation

/// Sends one `noul` question per file to Jev (`jev-latest`) and maps the answers to memberships.
/// Mirrors the payload of the original Python proxy. Requires `TYPESAFE_API_KEY`.
public struct JevClassifier: Sendable {
    public static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    public static let maxDocuments = 40
    public static let threshold = 0.55

    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public typealias Progress = @Sendable ([Membership]) async -> Void

    public let apiKey: String
    private let transport: Transport

    public init(apiKey: String, transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.apiKey = apiKey
        self.transport = transport
    }

    public static func resolveKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !key.isEmpty { return key }
        if let key = UserDefaults.standard.string(forKey: "TYPESAFE_API_KEY"), !key.isEmpty { return key }
        return nil
    }

    public func classify(folderName: String, items: [FileItem], onBatch: @escaping Progress = { _ in }) async throws -> [Membership] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw JevError.unauthorized }
        return try await withThrowingTaskGroup(of: (Int, [Membership]).self) { group in
            var next = 0
            var results: [Int: [Membership]] = [:]
            func enqueue() {
                let start = next
                let batch = Array(items[start..<min(start + Self.maxDocuments, items.count)])
                next += batch.count
                group.addTask { (start, try await classifyBatch(folderName: folderName, items: batch)) }
            }
            for _ in 0..<2 where next < items.count { enqueue() }
            while let (index, batch) = try await group.next() {
                try Task.checkCancellation()
                results[index] = batch
                await onBatch(batch)
                if next < items.count { enqueue() }
            }
            return results.keys.sorted().flatMap { results[$0]! }
        }
    }

    private func classifyBatch(folderName: String, items: [FileItem]) async throws -> [Membership] {
        try Task.checkCancellation()
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.payload(folderName: folderName, items: items))

        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw JevError.unavailable }
        if http.statusCode == 401 || http.statusCode == 403 { throw JevError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw JevError.unavailable }
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try Self.parse(items: items, result: result)
    }

    static func payload(folderName: String, items: [FileItem]) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        let state: [String: Any] = [
            "virtual_folder": folderName,
            "documents": items.enumerated().map { index, item in
                ["id": String(index), "name": item.name, "kind": item.isDirectory ? "folder" : item.ext.uppercased(), "modified": formatter.string(from: item.modified), "size": item.size]
            },
        ]
        var questions: [String: Any] = [:]
        for (index, item) in items.enumerated() {
            questions[String(index)] = [
                "type": "noul",
                "instructions": "The virtual folder is named: '\(folderName)'. Would the file '\(item.name)' meaningfully belong in that collection? Use the filename, kind, modification date, and ordinary user intent. Be selective: related is not enough; it should be useful for the named purpose.",
            ]
        }
        let stateJSON = String(data: try! JSONSerialization.data(withJSONObject: state), encoding: .utf8)!
        return ["model": "jev-latest", "state": stateJSON, "questions": questions]
    }

    static func parse(items: [FileItem], result: [String: Any]) throws -> [Membership] {
        let answers = result["answers"] as? [String: Any] ?? [:]
        return try items.enumerated().map { index, item in
            guard let answer = answers[String(index)] as? [String: Any],
                  let number = answer["noul"] as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(),
                  (0...1).contains(number.doubleValue) else {
                throw JevError.invalidAnswer(item.name)
            }
            let score = number.doubleValue
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
