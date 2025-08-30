import Foundation
import SwiftUI

@MainActor
final class GameState: ObservableObject {
    @Published var heroHole: [Card] = []
    @Published var board: [Card] = []
    @Published var opponents: Int = 1

    @Published var equity = EquityResult(win: 0, tie: 0)
    @Published var ips: Int = 0
    @Published var handDistribution: [HandRank.Category: Double] = [:]
    
    @Published var isCalculating: Bool = false
    @Published var bestHand: Set<Card> = []

    private let calc = EquityCalculator()
    // 用于“防抖”的计算任务
    private var calculationTask: Task<Void, Never>?

    init() {
        requestRecalculation(debounce: 0) // 初始加载
    }

    // MARK: - Card Management
    func addHeroCard(_ card: Card) {
        if heroHole.count < 2 && !isCardUsed(card) {
            heroHole.append(card)  // 立即更新UI
            requestRecalculation() // 延迟并防抖计算
        }
    }
    
    func removeHeroCard(_ card: Card) {
        heroHole.removeAll { $0 == card }
        requestRecalculation()
    }

    func addBoardCard(_ card: Card) {
        if board.count < 5 && !isCardUsed(card) {
            board.append(card)
            requestRecalculation()
        }
    }
    
    func removeBoardCard(_ card: Card) {
        board.removeAll { $0 == card }
        requestRecalculation()
    }

    func setOpponents(_ n: Int) {
        opponents = max(1, min(8, n))
        requestRecalculation()
    }
    
    func isCardUsed(_ card: Card) -> Bool {
        (heroHole + board).contains(card)
    }

    func clear() {
        heroHole.removeAll()
        board.removeAll()
        requestRecalculation()
    }

    // MARK: - Calculation Logic
    
    /// 防抖动的计算请求方法
    private func requestRecalculation(debounce delay: TimeInterval = 0.3) {
        // 取消上一个正在等待的计算任务，实现防抖
        calculationTask?.cancel()

        calculationTask = Task {
            do {
                // 等待一小段时间
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // 执行实际的计算
                await self.recalc()
            } catch {
                // 如果任务在 sleep 期间被取消，会抛出错误，我们直接返回即可
                return
            }
        }
    }

    /// 实际执行计算的函数 (现在由 requestRecalculation 调用)
    private func recalc() async {
        self.isCalculating = true

        // --- 只有当有2张手牌，并且 board 牌数为 0, 3, 4, 5 (Preflop, Flop, Turn, River) 时才计算 ---
        let shouldCalculate = heroHole.count == 2 && [0, 3, 4, 5].contains(board.count)

        if shouldCalculate {
            await calc.compute(hole: heroHole, oppCount: opponents, board: board, targetIterations: 120_000)
            self.equity = calc.result
            self.ips = calc.iterationsPerSecond
            
            // --- 统一使用计算器返回的牌型分布，并修复了 River 阶段分布清零的问题 ---
            self.handDistribution = calc.distribution

            if board.count == 5 {
                // 在 River 阶段，计算并高亮最佳手牌组合
                let (_, winningCards) = PokerHandEvaluator.evaluateAndGetBestCards(sevenCards: heroHole + board)
                self.bestHand = Set(winningCards)
            } else {
                self.bestHand = []
            }
        } else {
            // 其他情况（如只有一张手牌，或board有1、2张牌），重置所有计算结果
            self.equity = EquityResult(win: 0, tie: 0)
            self.ips = 0
            self.handDistribution = [:]
            self.bestHand = []
        }
        
        self.isCalculating = false
    }
}
