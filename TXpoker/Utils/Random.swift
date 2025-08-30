extension Array {
    mutating func fastShuffleInPlace<RNG: RandomNumberGenerator>(_ rng: inout RNG) {
        if count < 2 { return }
        for i in indices.dropLast() {
            let j = Int.random(in: i..<count, using: &rng)
            if i != j { self.swapAt(i, j) }
        }
    }
}
