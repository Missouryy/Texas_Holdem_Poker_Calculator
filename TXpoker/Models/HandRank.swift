struct HandRank: Comparable, Hashable {
    enum Category: Int { // 7张选5张最佳
        case highCard = 1, pair, twoPair, trips, straight, flush, fullHouse, quads, straightFlush
    }
    let category: Category
    /// 降序 5 个数字：主牌 + 踢脚
    let kickers: [Int]

    static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
        let la = lhs.kickers
        let ra = rhs.kickers
        for i in 0..<min(la.count, ra.count) {
            if la[i] != ra[i] { return la[i] < ra[i] }
        }
        return la.count < ra.count
    }
}

extension HandRank.Category: Hashable {}
extension HandRank.Category {
    var label: String {
        switch self {
        case .straightFlush: return "同花顺"
        case .quads: return "四条"
        case .fullHouse: return "葫芦"
        case .flush: return "同花"
        case .straight: return "顺子"
        case .trips: return "三条"
        case .twoPair: return "两对"
        case .pair: return "一对"
        case .highCard: return "高牌"
        }
    }
}
