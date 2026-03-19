import Foundation
import CoreServices

/// Watches the Claude projects directory for changes using FSEventStream.
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let callback: () -> Void

    init(path: String, callback: @escaping () -> Void) {
        self.callback = callback

        let pathsToWatch = [path] as CFArray

        // Use passRetained to prevent dangling pointer in callback
        var context = FSEventStreamContext()
        context.info = Unmanaged.passRetained(self).toOpaque()

        context.release = { info in
            guard let info else { return }
            Unmanaged<FileWatcher>.fromOpaque(info).release()
        }

        stream = FSEventStreamCreate(
            nil,
            { (_, info, _, _, _, _) in
                guard let info else { return }
                let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
                DispatchQueue.main.async {
                    watcher.callback()
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0, // 2 second latency for debouncing
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
    }

    func start() {
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
