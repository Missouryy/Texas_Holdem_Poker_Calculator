import Foundation
import Combine

struct EquityResult {
    var win: Double
    var tie: Double
    var lose: Double { max(0, 1.0 - win - tie) }
}

@MainActor
final class EquityCalculator: ObservableObject {
    @Published var result = EquityResult(win: 0, tie: 0)
    @Published var iterationsPerSecond: Int = 0
    @Published var distribution: [HandRank.Category: Double] = [:]

    private var cache = NSCache<NSString, NSNumber>() // 缓存 7 张牌评估结果（哈希）

    func reset() {
        result = EquityResult(win: 0, tie: 0)
        iterationsPerSecond = 0
        distribution = [:]
    }

    /// 自适应：未知牌较少时做精确枚举；未知牌较多采用 Monte Carlo 并发模拟
    func compute(hole: [Card], oppCount: Int, board: [Card], targetIterations: Int = 100_000) async {
        let used = hole + board
        var deck = Deck()
        deck.remove(used)

        let unknownBoard = 5 - board.count
        let unknownOppCards = max(0, oppCount * 2)

        // 精确枚举阈值：剩余待发牌 <= 3 走全枚举
        let remainToDeal = unknownBoard + unknownOppCards
        if remainToDeal <= 3 {
            let r = await exactEnumerate(hole: hole, board: board, deck: deck.cards, oppCount: oppCount)
            self.result = r
            return
        }

        // Monte Carlo + 并发
        let cores = max(2, ProcessInfo.processInfo.processorCount - 1)
        let perTask = targetIterations / cores

        var totalWins = 0
        var totalTies = 0
        var totalTrials = 0

        let start = Date()
        await withTaskGroup(of: (wins: Int, ties: Int, trials: Int, hist: [Int: Int]).self) { group in
            for _ in 0..<cores {
                group.addTask(priority: .userInitiated) { [cache] in
                    var localWins = 0, localTies = 0, localTrials = 0
                    var localHist: [Int: Int] = [:]
                    var rng = SystemRandomNumberGenerator()
                    var deckLocal = deck.cards
                    for _ in 0..<perTask {
                        deckLocal.fastShuffleInPlace(&rng)
                        // 抽取对手、翻公共牌
                        var idx = 0
                        var oppHands: [[Card]] = []
                        for _ in 0..<oppCount {
                            let c1 = deckLocal[idx]; idx += 1
                            let c2 = deckLocal[idx]; idx += 1
                            oppHands.append([c1, c2])
                        }
                        var simBoard = board
                        for _ in 0..<unknownBoard {
                            simBoard.append(deckLocal[idx]); idx += 1
                        }
                        let heroRank = Self.rank7(hole + simBoard, cache: cache)
                        localHist[heroRank.category.rawValue, default: 0] += 1
                        var bestOpp: HandRank = .init(category: .highCard, kickers: [0])
                        var sameCount = 0
                        for opp in oppHands {
                            let r = Self.rank7(opp + simBoard, cache: cache)
                            if r > bestOpp { bestOpp = r; sameCount = 1 }
                            else if r == bestOpp { sameCount += 1 }
                        }
                        if heroRank > bestOpp { localWins += 1 }
                        else if heroRank == bestOpp { localTies += 1 }
                        localTrials += 1
                    }
                    return (localWins, localTies, localTrials, localHist)
                }
            }

            var aggHist: [Int: Int] = [:]
            for await (w, t, n, h) in group {
                totalWins += w; totalTies += t; totalTrials += n
                for (k, v) in h { aggHist[k, default: 0] += v }
                let dt = max(0.001, Date().timeIntervalSince(start))
                let ips = Int(Double(totalTrials) / dt)
                await MainActor.run {
                    self.iterationsPerSecond = ips
                    self.result = EquityResult(win: Double(totalWins)/Double(totalTrials),
                                               tie: Double(totalTies)/Double(totalTrials))
                    var out: [HandRank.Category: Double] = [:]
                    for (k, v) in aggHist {
                        if let cat = HandRank.Category(rawValue: k) {
                            out[cat] = Double(v)/Double(max(1, totalTrials))
                        }
                    }
                    self.distribution = out
                }
            }
        }
    }

    /// 精确枚举
    private func exactEnumerate(hole: [Card], board: [Card], deck: [Card], oppCount: Int) async -> EquityResult {
        let unknownBoard = 5 - board.count
        let boardChoices = Combinatorics.combinations(deck, k: unknownBoard)
        var wins = 0, ties = 0, trials = 0
        var hist: [Int: Int] = [:]

        for bAdd in boardChoices {
            let curBoard = board + bAdd
            var remaining = deck
            for c in bAdd { if let i = remaining.firstIndex(of: c) { remaining.remove(at: i) } }

            let oppHandsChoices = Combinatorics.combinations(remaining, k: oppCount*2)
            for oppFlat in oppHandsChoices {
                var oppHands: [[Card]] = []
                var i = 0
                while i < oppFlat.count {
                    oppHands.append([oppFlat[i], oppFlat[i+1]])
                    i += 2
                }

                let heroRank = Self.rank7(hole + curBoard, cache: cache)
                hist[heroRank.category.rawValue, default: 0] += 1

                var bestOpp: HandRank = .init(category: .highCard, kickers: [0])
                var sameCount = 0
                for opp in oppHands {
                    let r = Self.rank7(opp + curBoard, cache: cache)
                    if r > bestOpp { bestOpp = r; sameCount = 1 }
                    else if r == bestOpp { sameCount += 1 }
                }
                if heroRank > bestOpp { wins += 1 }
                else if heroRank == bestOpp { ties += 1 }
                trials += 1
            }
        }

        let win = Double(wins)/Double(max(1, trials))
        let tie = Double(ties)/Double(max(1, trials))

        // ⬇️ 这里更新分布
        await MainActor.run {
            var out: [HandRank.Category: Double] = [:]
            for (k, v) in hist {
                if let cat = HandRank.Category(rawValue: k) {
                    out[cat] = Double(v) / Double(max(1, trials))
                }
            }
            self.distribution = out
            self.iterationsPerSecond = 0 // 枚举时不显示迭代速率
        }

        return EquityResult(win: win, tie: tie)
    }

    // MARK: - 缓存包装
    nonisolated(unsafe) private static func rank7(_ cards: [Card], cache: NSCache<NSString, NSNumber>) -> HandRank {
        var key = ""
        for c in cards.sorted(by: { $0.rankIndex < $1.rankIndex }) {
            key.append("\(c.rankIndex*4 + c.suitIndex),")
        }
        let k = key as NSString
        if let v = cache.object(forKey: k) {
            return decodeHandRank(Int32(truncating: v))
        }
        let r = PokerHandEvaluator.evaluate(sevenCards: cards)
        cache.setObject(NSNumber(value: encodeHandRank(r)), forKey: k)
        return r
    }

    nonisolated(unsafe) private static func encodeHandRank(_ r: HandRank) -> Int32 {
        var v = Int32(r.category.rawValue & 0xF)
        var shift: Int32 = 4
        for k in r.kickers.prefix(5) {
            v |= (Int32(k) & 0x1F) << shift
            shift += 5
        }
        return v
    }

    nonisolated(unsafe) private static func decodeHandRank(_ v: Int32) -> HandRank {
        let cat = HandRank.Category(rawValue: Int(v & 0xF)) ?? .highCard
        var shift: Int32 = 4
        var ks: [Int] = []
        for _ in 0..<5 {
            ks.append(Int((v >> shift) & 0x1F))
            shift += 5
        }
        return HandRank(category: cat, kickers: ks)
    }
}
