//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct LibraryView: View {
    @State private var showingCreateSheet = false
    @ObservedObject private var libraryManager = LibraryManager.shared
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                libraryContent
            }
        } else {
            NavigationView {
                libraryContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var libraryContent: some View {
        VStack {
            if libraryManager.collections.isEmpty {
                VStack {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No collections yet")
                        .font(.title2)
                        .padding(.top)
                    Text("Create your first collection to organize your media")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Create Collection") {
                        showingCreateSheet = true
                    }
                    .padding(.top)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(libraryManager.collections) { collection in
                        NavigationLink(destination: CollectionDetailView(collectionId: collection.id)) {
                            HStack {
                                Image(systemName: collection.name == "Bookmarks" ? "bookmark.fill" : "folder")
                                    .foregroundColor(collection.name == "Bookmarks" ? .yellow : .primary)
                                VStack(alignment: .leading) {
                                    Text(collection.name)
                                        .fontWeight(collection.name == "Bookmarks" ? .semibold : .regular)
                                    if let desc = collection.description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(collection.items.count) items")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indices in
                        for index in indices {
                            libraryManager.deleteCollection(libraryManager.collections[index])
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Library")
        .navigationBarItems(trailing: Button(action: {
            showingCreateSheet = true
        }) {
            Image(systemName: "plus")
        })
        .sheet(isPresented: $showingCreateSheet) {
            CreateCollectionView()
        }
    }
}

#Preview {
    LibraryView()
}
