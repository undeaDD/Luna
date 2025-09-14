//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 08/09/25.
//

import Foundation

class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    
    @Published var collections: [LibraryCollection] = []
    @Published var bookmarkedItems: [LibraryItem] = []
    
    private let collectionsKey = "libraryCollections"
    private let bookmarksKey = "libraryBookmarks"
    
    private init() {
        load()
        createDefaultBookmarksCollection()
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: collectionsKey),
           let decoded = try? JSONDecoder().decode([LibraryCollection].self, from: data) {
            collections = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            bookmarkedItems = decoded
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: collectionsKey)
        }
        
        if let data = try? JSONEncoder().encode(bookmarkedItems) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
    
    private func createDefaultBookmarksCollection() {
        if !collections.contains(where: { $0.name == "Bookmarks" }) {
            let bookmarksCollection = LibraryCollection(name: "Bookmarks", description: "Your bookmarked items")
            collections.insert(bookmarksCollection, at: 0)
            save()
        }
    }
    
    func createCollection(name: String, description: String? = nil) {
        let new = LibraryCollection(name: name, description: description)
        collections.append(new)
        save()
    }
    
    func deleteCollection(_ collection: LibraryCollection) {
        guard collection.name != "Bookmarks" else { return }
        collections.removeAll { $0.id == collection.id }
        save()
    }
    
    func addItem(to collectionId: UUID, item: LibraryItem) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }),
              !collections[index].items.contains(where: { $0.id == item.id }) else { return }
        collections[index].items.append(item)
        save()
    }
    
    func removeItem(from collectionId: UUID, item: LibraryItem) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[index].items.removeAll { $0.id == item.id }
        save()
    }
    
    func isItemInCollection(_ collectionId: UUID, item: LibraryItem) -> Bool {
        guard let col = collections.first(where: { $0.id == collectionId }) else { return false }
        return col.items.contains { $0.id == item.id }
    }
    
    func collectionsContainingItem(_ item: LibraryItem) -> [LibraryCollection] {
        return collections.filter { $0.items.contains { $0.id == item.id } }
    }
    
    // MARK: - Bookmark Functions
    func toggleBookmark(for searchResult: TMDBSearchResult) {
        let item = LibraryItem(searchResult: searchResult)
        
        if let bookmarksCollection = collections.first(where: { $0.name == "Bookmarks" }) {
            if isItemInCollection(bookmarksCollection.id, item: item) {
                removeItem(from: bookmarksCollection.id, item: item)
            } else {
                var newItem = item
                newItem.dateAdded = Date()
                addItem(to: bookmarksCollection.id, item: newItem)
            }
        }
    }
    
    func isBookmarked(_ searchResult: TMDBSearchResult) -> Bool {
        let item = LibraryItem(searchResult: searchResult)
        guard let bookmarksCollection = collections.first(where: { $0.name == "Bookmarks" }) else { return false }
        return isItemInCollection(bookmarksCollection.id, item: item)
    }
}
