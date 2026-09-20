import Foundation

/// Bundled sample files so anyone can try the app without making their own.
///
/// Jev only ever classifies file metadata (name, kind, modified date, size);
/// file contents stay on the Mac. So these samples are intentionally empty:
/// the filenames are the whole demo. Try "Stuff for my Japan trip" or
/// "my Python learning materials" and watch them gather.
enum DemoFiles {
    static let folderName = "LivingFoldersDemo"

    /// Copies the bundled samples to a fresh temp folder and returns its URL.
    /// The folder is recreated from scratch on every call, so the demo
    /// always starts clean.
    static func prepare() throws -> URL {
        guard let source = Bundle.module.url(forResource: "DemoFiles", withExtension: nil) else {
            throw DemoFilesError.missingResource
        }
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)
        return dest
    }
}

enum DemoFilesError: Error {
    case missingResource
}
