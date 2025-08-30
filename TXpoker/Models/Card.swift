import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

enum Suit: String, CaseIterable, Codable, Hashable {
    case spades = "♠️"
    case hearts = "♥️"
    case clubs = "♣️"
    case diamonds = "♦️"



    var color: Color {
        switch self {
        case .clubs, .spades: return .primary
        case .hearts, .diamonds: return .red
        }
    }
}

enum Rank: Int, CaseIterable, Codable, Hashable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    var short: String {
        switch self {
        case .ten: return "T"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(rawValue)
        }
    }
}

struct Card: Identifiable, Hashable, Codable {
    let suit: Suit
    let rank: Rank
    var id: String { "\(rank.rawValue)-\(suit.rawValue)" }

    // 评估辅助字段
    var rankIndex: Int { rank.rawValue - 2 } // 0..12
    var suitIndex: Int { Suit.allCases.firstIndex(of: suit)! } // 0..3
}

extension Array where Element == Card {
    var descriptionText: String {
        map { "\($0.rank.short)\($0.suit.rawValue)" }.joined(separator: " ")
    }
}

extension UTType {
    static let playingCard = UTType(exportedAs: "com.missouryy.txpoker.card")
}

extension Card: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .playingCard)
    }
}
