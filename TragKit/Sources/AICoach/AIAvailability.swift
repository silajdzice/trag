import Foundation
import FoundationModels

/// Whether the on-device model can be used. The app must work fully without it.
public enum AIAvailability: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        /// This iPhone can't run Apple Intelligence (e.g. iPhone 13).
        case deviceNotEligible
        /// Apple Intelligence is off in Settings.
        case appleIntelligenceNotEnabled
        /// The model is still downloading or preparing.
        case modelNotReady
        case unknown
    }

    case available
    case unavailable(Reason)

    public static var current: AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            return .unavailable(.modelNotReady)
        case .unavailable:
            return .unavailable(.unknown)
        }
    }

    public var isAvailable: Bool { self == .available }

    /// The model doesn't speak every UI language (Bosnian isn't supported), so AI text may be in English.
    public static func supportsUserLanguage(_ locale: Locale = .current) -> Bool {
        SystemLanguageModel.default.supportsLocale(locale)
    }
}
