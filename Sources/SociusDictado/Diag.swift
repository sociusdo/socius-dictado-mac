import Foundation
import AppKit

/// Tiny append-only diagnostic log so we can see what actually happened during a
/// paste attempt. Lives at ~/Library/Application Support/SociusDictado/debug.log.
enum Diag {
    private static let url: URL = {
        let base = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SociusDictado", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("debug.log")
    }()

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    static func log(_ msg: String) {
        let line = "\(fmt.string(from: Date()))  \(msg)\n"
        NSLog("SociusDictado: \(msg)")
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            h.seekToEndOfFile()
            h.write(data)
        } else {
            try? data.write(to: url)
        }
    }
}
