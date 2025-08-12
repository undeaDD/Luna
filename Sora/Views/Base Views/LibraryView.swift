//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct LibraryView: View {
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
            Image(systemName: "books.vertical.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 60))
            
            Text("Your Library")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            List {
                HStack {
                    Image(systemName: "book.fill")
                    Text("Favorite Books")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "bookmark.fill")
                    Text("Bookmarks")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "clock.fill")
                    Text("Recently Read")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Library")
    }
}

#Preview {
    LibraryView()
}
