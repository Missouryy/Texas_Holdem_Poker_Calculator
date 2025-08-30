import SwiftUI
import Foundation

struct CardView: View {
    let card: Card
    var large: Bool = false

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        let w: CGFloat = large ? 64 : 45
        let h = w * 1.4
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)

            VStack(spacing: 4) {
                Text(card.suit.rawValue)
                    .font(.system(size: w*0.36))
                    .foregroundStyle(card.suit.color)
                Text(card.rank.short)
                    .font(.system(size: w*0.32, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: w, height: h)
        .rotationEffect(.degrees(isDragging ? 3 : 0))
        .offset(dragOffset)
        .animation(.interpolatingSpring(stiffness: 140, damping: 16), value: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    isDragging = true
                    dragOffset = v.translation
                }
                .onEnded { v in
                    withAnimation(.interpolatingSpring(stiffness: 160, damping: 18)) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
        )
        .accessibilityLabel("\(card.rank.short) \(card.suit.rawValue)")
    }
}
