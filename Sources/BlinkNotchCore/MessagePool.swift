public struct Message: Equatable, Sendable {
    public let headline: String
    public let from: String

    public init(headline: String, from: String) {
        self.headline = headline
        self.from = from
    }
}

public struct MessagePool {
    /// Small grey caps line above the headline, as in the approved mockup.
    public static let kicker = "MAIL · NOW"

    public static let all: [Message] = [
        Message(headline: "Blink, you goof.", from: "your eyeballs"),
        Message(headline: "Your cornea is filing a complaint.", from: "Dry Eye Dept."),
        Message(headline: "Re: Re: Re: BLINK.", from: "your optic nerve"),
        Message(headline: "URGENT: eyelids available.", from: "Management"),
        Message(headline: "You have 1 unread blink.", from: "your face"),
        Message(headline: "Staring contest with the screen: you're losing.", from: "the Pixel Referee"),
        Message(headline: "Your tear ducts miss you.", from: "Tear Duct HR"),
        Message(headline: "Congrats! You've been pre-approved for a blink.", from: "Eyelid Rewards"),
        Message(headline: "Fwd: Fwd: Please close these two things.", from: "your eyelids"),
        Message(headline: "Moist eyes are happy eyes.", from: "the Hydration Committee"),
        Message(headline: "Final notice: unblinked time is overdue.", from: "Blink Collections"),
        Message(headline: "Psst. The screen will still be there.", from: "your eyeballs, again"),
    ]

    private let messages: [Message]
    private var last: Message?

    public init(messages: [Message] = MessagePool.all) {
        precondition(!messages.isEmpty, "MessagePool needs at least one message")
        self.messages = messages
    }

    public mutating func next() -> Message {
        var generator = SystemRandomNumberGenerator()
        return next(using: &generator)
    }

    public mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> Message {
        let candidates = messages.filter { $0 != last }
        let pick = (candidates.isEmpty ? messages : candidates).randomElement(using: &generator)!
        last = pick
        return pick
    }
}
