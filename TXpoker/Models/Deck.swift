struct Deck {
    private(set) var cards: [Card] = {
        var list: [Card] = []
        for s in Suit.allCases {
            for r in Rank.allCases { list.append(Card(suit: s, rank: r)) }
        }
        return list
    }()

    mutating func remove(_ used: [Card]) {
        let set = Set(used)
        cards.removeAll { set.contains($0) }
    }
}
