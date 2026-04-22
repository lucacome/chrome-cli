import Darwin
import Foundation

struct TabSwitchSource {
    private static let incrementalCacheWriteInterval = 25
    private let service: TabServicing
    private let cache: TabSwitchCache
    private let writeLine: (String) -> Void

    init(
        service: TabServicing,
        cache: TabSwitchCache,
        writeLine: @escaping (String) -> Void = TabSwitchSource.defaultWriteLine
    ) {
        self.service = service
        self.cache = cache
        self.writeLine = writeLine
    }

    func emitRowsToStdout() throws {
        DebugLog.write("tabs switch source: start bundleId=\(service.browserMetadata.bundleId)")
        var seenCompositeIDs: Set<String> = []
        var emittedRows = 0

        let cachedRows = try cache.readRows()
        DebugLog.write("tabs switch source: cachedRows=\(cachedRows.count)")
        for row in cachedRows {
            guard seenCompositeIDs.insert(row.compositeId).inserted else {
                continue
            }

            writeLine(row.tsvLine)
            emittedRows += 1
        }

        if !cachedRows.isEmpty {
            DebugLog.write("tabs switch source: returning cached rows only emittedRows=\(emittedRows)")
            return
        }

        try emitLiveRows(
            seenCompositeIDs: &seenCompositeIDs,
            emittedRows: &emittedRows,
            logPrefix: "tabs switch source"
        )
    }

    func emitRowsToStdoutLive() throws {
        DebugLog.write("tabs switch source live: start bundleId=\(service.browserMetadata.bundleId)")
        var seenCompositeIDs: Set<String> = []
        var emittedRows = 0

        DebugLog.write("tabs switch source live: cachedRows=0 (live-only mode)")

        try emitLiveRows(
            seenCompositeIDs: &seenCompositeIDs,
            emittedRows: &emittedRows,
            logPrefix: "tabs switch source live"
        )
    }

    private func emitLiveRows(
        seenCompositeIDs: inout Set<String>,
        emittedRows: inout Int,
        logPrefix: String
    ) throws {
        var freshRows: [TabSwitchRow] = []
        var freshSeenIDs: Set<String> = []
        var streamedTabs = 0
        var emittedFreshRows = 0

        try service.streamTabs { tab in
            streamedTabs += 1
            let row = TabSwitchRow(tab: tab)

            if freshSeenIDs.insert(row.compositeId).inserted {
                freshRows.append(row)
                if freshRows.count == 1 || freshRows.count % Self.incrementalCacheWriteInterval == 0 {
                    do {
                        try cache.writeRows(freshRows)
                    } catch {
                        DebugLog.write("\(logPrefix): incremental cache write failed at count=\(freshRows.count) error=\(error.localizedDescription)")
                    }
                }
            }

            if seenCompositeIDs.insert(row.compositeId).inserted {
                writeLine(row.tsvLine)
                emittedRows += 1
                emittedFreshRows += 1
            }
        }

        do {
            try cache.writeRows(freshRows)
        } catch {
            DebugLog.write("\(logPrefix): final cache write failed count=\(freshRows.count) error=\(error.localizedDescription)")
        }
        DebugLog.write(
            "\(logPrefix): done streamedTabs=\(streamedTabs) emittedRows=\(emittedRows) emittedFreshRows=\(emittedFreshRows) freshRowsForCache=\(freshRows.count) cachePath=\(cache.fileURL.path)"
        )
    }

    func refreshCache() throws {
        DebugLog.write("tabs switch refresh: start bundleId=\(service.browserMetadata.bundleId)")
        var freshRows: [TabSwitchRow] = []
        var seenCompositeIDs: Set<String> = []
        var streamedTabs = 0

        try service.streamTabs { tab in
            streamedTabs += 1
            let row = TabSwitchRow(tab: tab)
            if seenCompositeIDs.insert(row.compositeId).inserted {
                freshRows.append(row)
            }
        }

        try cache.writeRows(freshRows)
        DebugLog.write(
            "tabs switch refresh: done streamedTabs=\(streamedTabs) freshRowsForCache=\(freshRows.count) cachePath=\(cache.fileURL.path)"
        )
    }

    private static func defaultWriteLine(_ line: String) {
        FileHandle.standardOutput.write(Data(line.utf8))
        FileHandle.standardOutput.write(Data("\n".utf8))
        fflush(stdout)
    }
}
