//
//  Item.swift
//  TXpoker
//
//  Created by 严禹 on 2025/8/13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
