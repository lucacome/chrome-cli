import Foundation

enum TabSwitchCacheAge {
    static func cacheAgeSeconds(
        bundleId: String,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> Int? {
        let cache = TabSwitchCache(bundleId: bundleId)
        let path = cache.fileURL.path

        guard fileManager.fileExists(atPath: path) else {
            return nil
        }

        guard
            let attributes = try? fileManager.attributesOfItem(atPath: path),
            let modifiedDate = attributes[.modificationDate] as? Date
        else {
            return nil
        }

        return Int(now.timeIntervalSince(modifiedDate))
    }

    static func cacheAgeLabel(
        bundleId: String,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> String {
        guard let elapsedSeconds = cacheAgeSeconds(bundleId: bundleId, fileManager: fileManager, now: now) else {
            let cache = TabSwitchCache(bundleId: bundleId)
            if fileManager.fileExists(atPath: cache.fileURL.path) {
                return "unknown"
            }
            return "never"
        }
        return relativeAgeLabel(seconds: elapsedSeconds)
    }

    static func relativeAgeLabel(seconds: Int) -> String {
        if seconds <= 4 {
            return "just now"
        }

        if seconds < 60 {
            return "\(seconds)s ago"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }

        let days = hours / 24
        if days < 30 {
            return "\(days)d ago"
        }

        let months = days / 30
        if months < 12 {
            return "\(months)mo ago"
        }

        let years = days / 365
        return "\(years)y ago"
    }
}
