import Foundation

/// Minimal .env reader for the local source checkout.
///
/// A dev who clones the repo can drop `TYPESAFE_API_KEY=...` into `<repo>/.env`
/// instead of typing the key into Settings. `.env` is gitignored, so the key
/// never lands in the repo. Only the single key the app needs is read out.
public enum EnvFile {
    /// Parse dotenv content: `KEY=VALUE` lines, `#` comments, blank lines,
    /// an optional `export` prefix, and surrounding single/double quotes stripped.
    public static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let name = line[..<eq].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, let first = value.first, let last = value.last,
               (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value = String(value.dropFirst().dropLast())
            }
            if !name.isEmpty { result[name] = value }
        }
        return result
    }

    /// Load `<repoRoot>/.env` into a dictionary. Empty when the file is
    /// missing or unreadable — a missing .env is a normal state, not an error.
    public static func load(repoRoot: URL) -> [String: String] {
        let url = repoRoot.appendingPathComponent(".env")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parse(text)
    }

    /// The repo root is the checkout holding `.git`, found by walking up from
    /// the running .app bundle (same discovery the self-updater uses).
    public static func repoRoot(bundleURL: URL = Bundle.main.bundleURL) -> URL? {
        Updater.findSourceDir(from: bundleURL)
    }
}
