import Testing
@testable import BlinkNotchCore

@Suite struct MessagePoolTests {
    @Test func allHasAtLeastTenDistinctMessages() {
        #expect(MessagePool.all.count >= 10)
        #expect(Set(MessagePool.all.map(\.headline)).count == MessagePool.all.count)
    }

    @Test func firstMessageIsTheMockupCopy() {
        #expect(MessagePool.all[0] == Message(headline: "Blink, you goof.", from: "your eyeballs"))
        #expect(MessagePool.kicker == "MAIL · NOW")
    }

    @Test func neverRepeatsConsecutively() {
        var pool = MessagePool()
        var previous = pool.next()
        for _ in 0..<5_000 {
            let current = pool.next()
            #expect(current != previous)
            previous = current
        }
    }

    @Test func singleMessagePoolDoesNotHang() {
        let only = Message(headline: "Solo", from: "nobody")
        var pool = MessagePool(messages: [only])
        #expect(pool.next() == only)
        #expect(pool.next() == only)
        #expect(pool.next() == only)
    }
}
