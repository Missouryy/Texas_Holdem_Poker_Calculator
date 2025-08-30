import Foundation

struct PokerHandEvaluator {
    
    // MARK: - 新增函数：返回最佳牌型和对应的5张牌
    static func evaluateAndGetBestCards(sevenCards: [Card]) -> (rank: HandRank, cards: [Card]) {
        precondition(sevenCards.count == 7)
        let sorted = sevenCards.sorted { $0.rankIndex > $1.rankIndex }
        
        let initial: (HandRank, [Card]) = (HandRank(category: .highCard, kickers: [0]), [])
        
        let bestCombination = Combinatorics.combinations(sorted, k: 5).reduce(initial) { acc, fiveCardCombo in
            let currentRank = evaluate5(fiveCardCombo)
            if currentRank > acc.0 {
                return (currentRank, fiveCardCombo)
            }
            return acc
        }
        
        return bestCombination
    }
    
    // MARK: - 原始函数（仅返回 HandRank，用于胜率计算）
    static func evaluate(sevenCards: [Card]) -> HandRank {
        precondition(sevenCards.count == 7)
        let sorted = sevenCards.sorted { $0.rankIndex > $1.rankIndex }
        let best = Combinatorics.combinations(sorted, k: 5).reduce(HandRank(category: .highCard, kickers: [0])) { acc, five in
            let r = evaluate5(five)
            return max(acc, r)
        }
        return best
    }
    
    // MARK: - 5 张牌评估
    private static func evaluate5(_ cards: [Card]) -> HandRank {
        let c = cards.sorted { $0.rankIndex > $1.rankIndex }
        
        // ---------- 花色统计 ----------
        var suitCount = [0,0,0,0]
        for x in c { suitCount[x.suitIndex] += 1 }
        let flushSuit = suitCount.firstIndex(where: { $0 >= 5 })
        
        // ---------- 频次表 ----------
        var freq = Array(repeating: 0, count: 13)
        for x in c { freq[x.rankIndex] += 1 }
        
        // 唯一点数（降序）
        var uniqueRanks: [Int] = []
        for i in stride(from: 12, through: 0, by: -1) { if freq[i] > 0 { uniqueRanks.append(i) } }
        
        // ---------- 顺子检测 ----------
        var straightHigh = -1
        var streak = 1
        var prev = uniqueRanks.first ?? -1
        for i in 1..<uniqueRanks.count {
            if uniqueRanks[i] == prev - 1 {
                streak += 1
                prev = uniqueRanks[i]
                if streak >= 5 {
                    straightHigh = uniqueRanks[i-4] + 4
                    break
                }
            } else {
                streak = 1
                prev = uniqueRanks[i]
            }
        }
        let isWheel = uniqueRanks.contains(12) &&
                      uniqueRanks.contains(3) &&
                      uniqueRanks.contains(2) &&
                      uniqueRanks.contains(1) &&
                      uniqueRanks.contains(0)
        if straightHigh < 0 && isWheel { straightHigh = 3 } // 5-high 顺子
        
        // ---------- 同花 & 同花顺 ----------
        if let fs = flushSuit {
            let flushCards = c.filter { $0.suitIndex == fs }
                              .map { $0.rankIndex }
                              .sorted(by: >)
            
            // 同花顺检测
            var sfHigh = -1
            var sfStreak = 1
            var sfPrev = flushCards.first ?? -1
            for i in 1..<flushCards.count {
                if flushCards[i] == sfPrev - 1 {
                    sfStreak += 1
                    sfPrev = flushCards[i]
                    if sfStreak >= 5 {
                        sfHigh = flushCards[i-4] + 4
                        break
                    }
                } else {
                    sfStreak = 1
                    sfPrev = flushCards[i]
                }
            }
            if sfHigh < 0 && isWheel && flushCards.contains(12) {
                sfHigh = 3
            }
            if sfHigh >= 0 {
                return HandRank(category: .straightFlush, kickers: [sfHigh])
            }
            return HandRank(category: .flush, kickers: Array(flushCards.prefix(5)))
        }
        
        // ---------- 四条/葫芦/三条/两对/一对 ----------
        var fours: Int = -1
        var trips: [Int] = []
        var pairs: [Int] = []
        var singles: [Int] = []
        for i in stride(from: 12, through: 0, by: -1) {
            switch freq[i] {
            case 4: fours = i
            case 3: trips.append(i)
            case 2: pairs.append(i)
            case 1: singles.append(i)
            default: break
            }
        }
        
        if fours >= 0 {
            return HandRank(category: .quads, kickers: [fours] + Array(singles.prefix(1)))
        }
        if let t = trips.first, let p = pairs.first {
            return HandRank(category: .fullHouse, kickers: [t, p])
        }
        if straightHigh >= 0 {
            return HandRank(category: .straight, kickers: [straightHigh])
        }
        if let t = trips.first {
            return HandRank(category: .trips, kickers: [t] + Array(singles.prefix(2)))
        }
        if pairs.count >= 2 {
            return HandRank(category: .twoPair, kickers: [pairs[0], pairs[1]] + Array(singles.prefix(1)))
        }
        if let p = pairs.first {
            return HandRank(category: .pair, kickers: [p] + Array(singles.prefix(3)))
        }
        return HandRank(category: .highCard, kickers: singles.prefix(5).map { $0 })
    }
    
    // MARK: - 组合工具
    private struct Combinatorics {
        static func combinations<T>(_ source: [T], k: Int) -> [[T]] {
            guard k > 0, k <= source.count else { return k == 0 ? [[]] : [] }
            if k == 1 { return source.map { [$0] } }
            if k == source.count { return [source] }
            
            var result: [[T]] = []
            let rest = Array(source.dropFirst())
            let subCombinations = combinations(rest, k: k - 1)
            result += subCombinations.map { [source[0]] + $0 }
            result += combinations(rest, k: k)
            return result
        }
    }
}
