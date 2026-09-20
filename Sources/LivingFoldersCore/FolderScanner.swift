import Foundation

public enum FolderScanner {
    /// Lists the visible top-level entries of `root`, newest first.
    public static func scan(_ root: URL) throws -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey, .nameKey, .fileResourceIdentifierKey]
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        return urls.compactMap { url -> FileItem? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let isPackage = values.isPackage ?? false
            let isDirectory = (values.isDirectory ?? false) && !isPackage
            return FileItem(
                url: url,
                name: values.name ?? url.lastPathComponent,
                ext: url.pathExtension.lowercased(),
                isDirectory: isDirectory,
                size: Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate ?? .distantPast,
                fileIdentity: values.fileResourceIdentifier.map { String(describing: $0) }
            )
        }
        .sorted { $0.modified == $1.modified ? $0.id < $1.id : $0.modified > $1.modified }
    }
}
