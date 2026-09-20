import Foundation

public enum FolderScanner {
    /// Lists the visible top-level entries of `root`, newest first.
    public static func scan(_ root: URL) throws -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey, .nameKey]
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
                modified: values.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.modified > $1.modified }
    }
}
