//
//  LibraryCollection.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import Foundation

struct LibraryCollection: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var items: [LibraryItem] = []
    var description: String?
    
    static func == (lhs: LibraryCollection, rhs: LibraryCollection) -> Bool {
        lhs.id == rhs.id
    }
}
