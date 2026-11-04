import Foundation

public enum ReminderInterval: Int, CaseIterable, Sendable {
    case ten = 10, twenty = 20, thirty = 30, sixty = 60

    public static let defaultValue: ReminderInterval = .twenty

    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    public var menuTitle: String { "\(rawValue) minutes" }
}

public final class Settings {
    private static let intervalKey = "reminderIntervalMinutes"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var interval: ReminderInterval {
        get {
            // `object(forKey:)` so a missing key is distinguishable from a stored 0.
            guard let stored = defaults.object(forKey: Self.intervalKey) as? Int,
                  let interval = ReminderInterval(rawValue: stored) else {
                return .defaultValue
            }
            return interval
        }
        set { defaults.set(newValue.rawValue, forKey: Self.intervalKey) }
    }
}
