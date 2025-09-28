//
//  Item.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
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
