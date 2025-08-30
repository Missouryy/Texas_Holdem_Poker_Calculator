import SwiftUI

struct DeckPickerView: View {
    let onPick: (Card) -> Void
    let isUsed: (Card) -> Bool

    private let grid = [GridItem(.adaptive(minimum: 54), spacing: 8)]
    @GestureState private var dragOffset: CGSize = .zero
    @State private var draggingCard: Card?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid, spacing: 10) {
                ForEach(Suit.allCases, id: \.self) { s in
                    ForEach(Rank.allCases, id: \.self) { r in
                        let c = Card(suit: s, rank: r)
                        CardView(card: c)
                            .opacity(isUsed(c) ? 0.35 : 1)
                            .saturation(isUsed(c) ? 0 : 1)
                            .allowsHitTesting(!isUsed(c))
                            .offset(draggingCard == c ? dragOffset : .zero)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .updating($dragOffset) { value, state, _ in
                                        state = value.translation
                                    }
                                    .onChanged { _ in
                                        if !isUsed(c) {
                                            draggingCard = c
                                        }
                                    }
                                    .onEnded { _ in
                                        if !isUsed(c) {
                                            onPick(c)
                                        }
                                        draggingCard = nil
                                    }
                            )
                    }
                }
            }
            .padding()
        }
    }
}
