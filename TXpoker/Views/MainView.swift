import SwiftUI
import UIKit
import UniformTypeIdentifiers

// 立即放置
private struct InstantDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let addCardAction: (Card) -> Void
    let canAddCardCheck: (Card) -> Bool

    func dropEntered(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.1)) { isTargeted = true }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.1)) { isTargeted = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        _ = info.itemProviders(for: [UTType.playingCard]).first?.loadTransferable(type: Card.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let card):
                    if canAddCardCheck(card) {
                        addCardAction(card)
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                case .failure: break
                }
                withAnimation(.easeOut(duration: 0.1)) { isTargeted = false }
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }
}

struct MainView: View {
    @StateObject var state = GameState()
    
    @State private var isHeroTargeted = false
    @State private var isBoardTargeted = false
    
    @State private var heroDropTimer: Timer?
    @State private var boardDropTimer: Timer?
    
    @GestureState private var chipDragOffset = CGSize.zero

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [
                    Color(.sRGB, red: 0.06, green: 0.32, blue: 0.22, opacity: 1),
                    Color(.sRGB, red: 0.03, green: 0.22, blue: 0.16, opacity: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                
                GeometryReader { geo in
                    let W = geo.size.width
                    let H = geo.size.height
                    let leftW = min(280, W * 0.22)
                    let chipSize = leftW * 0.9
                    let padding: CGFloat = 16
                    
                    HStack(spacing: 20) {
                        leftColumn(width: leftW, height: H)
                        rightColumn(size: geo.size, leftW: leftW, height: H)
                            .offset(y: -40)
                    }
                    .padding(padding)

                    // --- 修正: 调用 chipView 时传入原始栏目宽度 `leftW` ---
                    chipView(columnWidth: leftW)
                        .position(
                            x: padding + leftW / 2,
                            y: padding + chipSize / 2
                        )
                        .offset(chipDragOffset)
                        .gesture(
                            DragGesture()
                                .updating($chipDragOffset) { value, state, _ in
                                    state = value.translation
                                }
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: chipDragOffset)
                }
            }
        }
    }

    private var displayCats: [HandRank.Category] {
        [.straightFlush, .quads, .fullHouse, .flush, .straight, .trips, .twoPair, .pair, .highCard].compactMap { $0 }
    }
    
    // --- 修正: chipView 接收 columnWidth，内部计算维持原始比例 ---
    @ViewBuilder
    private func chipView(columnWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.95, green: 0.9, blue: 0.7))
                .shadow(color: .black.opacity(0.4), radius: 8, x: 4, y: 4)

            ForEach(0..<6) { i in
                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 30, height: 10)
                    .offset(y: columnWidth * 0.4) // 使用栏目宽度计算
                    .rotationEffect(.degrees(Double(i) * 60))
            }

            Circle()
                .stroke(Color.yellow.opacity(0.8), lineWidth: 8)
                .frame(width: columnWidth * 0.7, height: columnWidth * 0.7) // 使用栏目宽度计算

            Circle()
                .fill(Color.white)
                .frame(width: columnWidth * 0.65, height: columnWidth * 0.65) // 使用栏目宽度计算
                .overlay(
                    VStack{
                        Text(state.isCalculating ? "..." : "\(Int(state.equity.win*100))%")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .contentTransition(.numericText())
                            .animation(.easeOut, value: state.equity.win)
                    }
                )
        }
        // 最终尺寸依然是栏目宽度的 90%
        .frame(width: columnWidth * 0.9, height: columnWidth * 0.9)
    }

    @ViewBuilder
    private func leftColumn(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 12) {
            Color.clear
                .frame(width: width * 0.9, height: width * 0.9)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .stroke(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(displayCats, id: \.self) { cat in
                        let v = state.handDistribution[cat] ?? 0
                        HStack(spacing: 8) {
                            Text(cat.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 40, alignment: .leading)

                            ProgressView(value: v)
                                .tint(.yellow)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Text("\(Int(v*100))%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundColor(.white)
                                .frame(minWidth: 35, maxWidth: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(15)
            }
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func rightColumn(size: CGSize, leftW: CGFloat, height: CGFloat) -> some View {
        let H = height
        let shouldHighlightBestHand = state.board.count == 5 && !state.bestHand.isEmpty
        
        VStack(spacing: 65) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHeroTargeted ? Color.yellow.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isHeroTargeted ? Color.yellow : Color.white.opacity(0.3),
                                        style: StrokeStyle(lineWidth: isHeroTargeted ? 2 : 1, dash: [4, 4]))
                        )
                        .frame(width: 130, height: 70)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { index in
                            if let card = state.heroHole.safeGet(at: index) {
                                CardView(card: card, large: false)
                                    .opacity(shouldHighlightBestHand && !state.bestHand.contains(card) ? 0.4 : 1.0)
                                    .shadow(color: .yellow, radius: shouldHighlightBestHand && state.bestHand.contains(card) ? 8 : 0)
                                    .frame(width: 45, height: 58)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                    .frame(width: 45, height: 58)
                            }
                        }
                    }
                }
                .scaleEffect(isHeroTargeted ? 1.1 : 1.0)
                .onDrop(of: [UTType.playingCard], delegate: InstantDropDelegate(
                    isTargeted: $isHeroTargeted,
                    addCardAction: { card in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            state.addHeroCard(card)
                        }
                    },
                    canAddCardCheck: { card in
                        state.heroHole.count < 2 && !state.isCardUsed(card)
                    }
                ))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isBoardTargeted ? Color.yellow.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isBoardTargeted ? Color.yellow : Color.white.opacity(0.3),
                                        style: StrokeStyle(lineWidth: isBoardTargeted ? 2 : 1, dash: [4, 4]))
                        )
                        .frame(width: 280, height: 70)
                    
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            ForEach(0..<5, id: \.self) { index in
                                if let card = state.board.safeGet(at: index) {
                                    CardView(card: card, large: false)
                                        .opacity(shouldHighlightBestHand && !state.bestHand.contains(card) ? 0.4 : 1.0)
                                        .shadow(color: .yellow, radius: shouldHighlightBestHand && state.bestHand.contains(card) ? 8 : 0)
                                        .frame(width: 45, height: 58)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        .frame(width: 45, height: 58)
                                }
                            }
                        }
                    }
                }
                .scaleEffect(isBoardTargeted ? 1.1 : 1.0)
                .onDrop(of: [UTType.playingCard], delegate: InstantDropDelegate(
                    isTargeted: $isBoardTargeted,
                    addCardAction: { card in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            state.addBoardCard(card)
                        }
                    },
                    canAddCardCheck: { card in
                        state.board.count < 5 && !state.isCardUsed(card)
                    }
                ))
                
                VStack(spacing: 4) {
                    HStack {
                        Text(getStageLabel())
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.3)))
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { state.clear() }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: shouldHighlightBestHand)
            .frame(height: 100)
            
            let allCards = Deck().cards
            let usedCards = Set(state.heroHole + state.board)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color(.sRGB, red: 0.08, green: 0.36, blue: 0.26, opacity: 1),
                        Color(.sRGB, red: 0.05, green: 0.28, blue: 0.20, opacity: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                
                VStack(spacing: 5) {
                    ForEach(Suit.allCases, id: \.self) { suit in
                        let suitCards = allCards.filter { $0.suit == suit }
                        HStack(spacing: -5) {
                            ForEach(suitCards) { card in
                                let isUsed = usedCards.contains(card)
                                CardView(card: card)
                                    .opacity(isUsed ? 0.35 : 1.0)
                                    .saturation(isUsed ? 0 : 1)
                                    .allowsHitTesting(!isUsed)
                                    .draggable(card) {
                                        CardView(card: card).frame(width: 60)
                                    }
                            }
                        }
                    }
                }
                .padding(10)
                .dropDestination(for: Card.self) { items, _ in
                    guard let card = items.first else { return false }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        if state.heroHole.contains(card) {
                            state.removeHeroCard(card)
                        } else if state.board.contains(card) {
                            state.removeBoardCard(card)
                        }
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    return true
                }
            }
            .frame(height: max(160, H*0.25))
        }
    }
    
    private func getStageLabel() -> String {
        switch state.board.count {
        case 0: return "Pre-Flop"
        case 3: return "Flop"
        case 4: return "Turn"
        case 5: return "River"
        default: return "\(state.board.count) / 5"
        }
    }
}

private extension Array {
    func safeGet(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    MainView()
}
