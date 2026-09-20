import Foundation

public struct FileItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let name: String
    public let ext: String
    public let isDirectory: Bool
    public let size: Int64
    public let modified: Date
    public let fileIdentity: String?

    public var id: String { url.path }

    public init(url: URL, name: String, ext: String, isDirectory: Bool, size: Int64, modified: Date, fileIdentity: String? = nil) {
        self.url = url
        self.name = name
        self.ext = ext
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.fileIdentity = fileIdentity
    }
}

public struct Membership: Hashable, Sendable {
    public let id: String
    public let belongs: Bool
    public let confidence: Double

    public init(id: String, belongs: Bool, confidence: Double) {
        self.id = id
        self.belongs = belongs
        self.confidence = confidence
    }
}
