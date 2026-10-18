import AICoach
import Foundation
import Observation

/// Which AI engine the user chose. Stored on device; defaults to Apple Intelligence where available.
@Observable
final class AISettings {
    private static let key = "trag.aiEngine"
    private static let off = "off"
    private let defaults: UserDefaults

    /// Engine id ("apple" or a model id), or "off".
    private(set) var selection: String

    /// Lets tests and previews pretend a device does or doesn't support Apple Intelligence.
    let appleIntelligence: AIAvailability

    init(defaults: UserDefaults = .standard, appleIntelligence: AIAvailability = .current) {
        self.defaults = defaults
        self.appleIntelligence = appleIntelligence
        selection = defaults.string(forKey: Self.key) ?? (appleIntelligence.isAvailable ? "apple" : Self.off)
    }

    var isOff: Bool { selection == Self.off }

    /// The chosen engine, if it can run right now.
    var selectedEngine: AIEngine? {
        guard let engine = AIEngine(id: selection) else { return nil }
        if case .appleIntelligence = engine, !appleIntelligence.isAvailable { return nil }
        return engine
    }

    func select(_ engine: AIEngine?) {
        selection = engine?.id ?? Self.off
        defaults.set(selection, forKey: Self.key)
    }

    func isSelected(_ engine: AIEngine) -> Bool { selection == engine.id }
}
