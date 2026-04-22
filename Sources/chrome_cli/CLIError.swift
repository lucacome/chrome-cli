import ArgumentParser
import Foundation

enum CLIError: Error, Equatable {
    case invalidInput(String)
    case browserUnavailable(String)
    case tabNotFound(windowId: Int, tabId: Int)
    case scriptFailure(String)

    var exitCode: Int32 {
        switch self {
        case .invalidInput:
            return 2
        case .browserUnavailable:
            return 3
        case .tabNotFound:
            return 4
        case .scriptFailure:
            return 5
        }
    }

    var message: String {
        switch self {
        case .invalidInput(let message):
            return message
        case .browserUnavailable(let message):
            return message
        case .tabNotFound(let windowId, let tabId):
            return "Could not find tab \(tabId) in window \(windowId)."
        case .scriptFailure(let message):
            return message
        }
    }

    static func from(_ error: Error) -> CLIError {
        if let cliError = error as? CLIError {
            return cliError
        }

        if let validationError = error as? ValidationError {
            return .invalidInput(validationError.message)
        }

        let errorType = String(reflecting: type(of: error))
        if errorType.contains("ArgumentParser") {
            return .invalidInput(String(describing: error))
        }

        return .scriptFailure(error.localizedDescription)
    }
}
