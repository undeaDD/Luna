//
//  CustomTabBar.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import SwiftUI

struct TabItem {
    let icon: String
    let title: String
    let index: Int
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        TabItem(icon: "house.fill", title: "Home", index: 0),
        TabItem(icon: "books.vertical.fill", title: "Library", index: 1),
        TabItem(icon: "magnifyingglass", title: "Search", index: 2),
        TabItem(icon: "gear", title: "Settings", index: 3)
    ]
    
    var body: some View {
        HStack(spacing: 40) {
            ForEach(tabs, id: \.index) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab.index
                ) {
                    selectedTab = tab.index
                }
            }
        }
        .frame(height: 50)
        .padding(.horizontal, 24)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 32)
        )
        .padding(.horizontal, 20)
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
