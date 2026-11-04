import Testing
@testable import BlinkNotchCore

@Suite struct AppInfoTests {
    @Test func nameAndBundleID() {
        #expect(AppInfo.name == "Blink Notch")
        #expect(AppInfo.bundleID == "dev.kshitiz.blinknotch")
    }
}
