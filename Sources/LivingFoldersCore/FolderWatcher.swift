import Foundation
import CoreServices

public final class FolderWatcher {
    private final class Callback {
        let changed: @Sendable () -> Void
        init(_ changed: @escaping @Sendable () -> Void) { self.changed = changed }
    }

    private var stream: FSEventStreamRef?
    private let callback: Callback

    public init(root: URL, onChange: @escaping @Sendable () -> Void) throws {
        callback = Callback(onChange)
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(callback).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<Callback>.fromOpaque(info).takeUnretainedValue().changed()
            },
            &context, [root.resolvingSymlinksInPath().path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1, FSEventStreamCreateFlags(flags)
        ) else { throw CocoaError(.fileReadUnknown) }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        guard FSEventStreamStart(stream) else {
            stop()
            throw CocoaError(.fileReadNoPermission)
        }
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
