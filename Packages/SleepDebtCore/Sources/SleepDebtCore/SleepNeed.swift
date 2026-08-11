/// A person's configured sleep need (the mockup's "Besoin réglé").
public struct SleepNeed: Hashable, Codable, Sendable {
    public let duration: SleepDuration

    public init(_ duration: SleepDuration) {
        self.duration = duration
    }
}
