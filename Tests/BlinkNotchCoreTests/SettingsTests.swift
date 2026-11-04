import Testing
@testable import BlinkNotchCore

@Suite struct SettingsTests {
    @Test func defaultIsTwentyMinutes() {
        #expect(Settings(defaults: freshDefaults()).interval == .twenty)
        #expect(ReminderInterval.defaultValue == .twenty)
    }

    @Test func setIntervalSurvivesNewInstance() {
        let defaults = freshDefaults()
        Settings(defaults: defaults).interval = .thirty
        #expect(Settings(defaults: defaults).interval == .thirty)
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        let defaults = freshDefaults()
        defaults.set(7, forKey: "reminderIntervalMinutes")
        #expect(Settings(defaults: defaults).interval == .twenty)
    }

    @Test func secondsAndTitles() {
        #expect(ReminderInterval.sixty.seconds == 3600)
        #expect(ReminderInterval.ten.menuTitle == "10 minutes")
        #expect(ReminderInterval.allCases.map(\.menuTitle) == ["10 minutes", "20 minutes", "30 minutes", "60 minutes"])
    }
}
