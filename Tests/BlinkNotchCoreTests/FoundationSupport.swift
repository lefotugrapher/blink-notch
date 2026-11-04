// The Command Line Tools' Swift Testing install is missing its Foundation
// overlay module, so a file that imports both `Testing` and `Foundation` does
// not compile. Test files therefore never import Foundation; anything that
// needs it goes through the helpers in this file.
import Foundation

func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString)!
}

func date(_ secondsSince1970: Double) -> Date {
    Date(timeIntervalSince1970: secondsSince1970)
}

/// Foundation's `Date + TimeInterval` operator is not visible in files that
/// cannot import Foundation, so provide it module-wide for tests.
func + (lhs: Date, rhs: Double) -> Date { lhs.addingTimeInterval(rhs) }
