import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// Whether the on-device model can be used. The app must work fully without it.
public enum AIAvailability: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public static var current: AIAvailability {
        #if canImport(FoundationModels)
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(reason: String(describing: reason))
            }
        #else
            return .unavailable(reason: "FoundationModels not available on this platform")
        #endif
    }
}
