/// A trivial deterministic `RandomNumberGenerator` — Swift's
/// `SystemRandomNumberGenerator` isn't seedable, and `GrainTexture` only
/// needs its output to be stable and cheap, not cryptographically
/// anything. xorshift64, not a security-relevant use.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
