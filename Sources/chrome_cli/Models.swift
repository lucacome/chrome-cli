import Foundation

enum BuildInfo {
    static let version = BuildVersion.value
}

struct BrowserMetadata: Codable, Equatable {
    let bundleId: String
}

struct TabIdentifier: Codable, Equatable {
    let windowId: Int
    let tabId: Int
}

struct TabRecord: Codable, Equatable {
    let windowId: Int
    let windowName: String
    let tabId: Int
    let title: String
    let url: String
}

struct ListTabsResponse: Codable, Equatable {
    let browser: BrowserMetadata
    let tabs: [TabRecord]
}

struct ActivateTabResponse: Codable, Equatable {
    let browser: BrowserMetadata
    let tab: TabIdentifier
    let focused: Bool
}

struct CloseTabResponse: Codable, Equatable {
    let browser: BrowserMetadata
    let tab: TabIdentifier
    let closed: Bool
}

struct VersionResponse: Codable, Equatable {
    let version: String
}

struct ErrorPayload: Codable, Equatable {
    let code: Int
    let message: String
}

struct ErrorResponse: Codable, Equatable {
    let error: ErrorPayload
}
