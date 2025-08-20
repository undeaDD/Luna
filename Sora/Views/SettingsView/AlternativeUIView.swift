//
//  AlternativeUIView.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import SwiftUI

struct AlternativeUIView: View {
    @AppStorage("seasonMenu") private var useSeasonMenu = false
    @StateObject private var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alternative Season Menu")
                        Text("Use dropdown menu instead of horizontal scroll for seasons")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useSeasonMenu)
                }
            } header: {
                Text("DISPLAY OPTIONS")
            } footer: {
                Text("The alternative season menu uses a dropdown instead of a horizontal scroll for selecting seasons.")
            }
            
            Section {
                    ColorPicker("Accent Color", selection: $accentColorManager.currentAccentColor)
                        .onChange(of: accentColorManager.currentAccentColor) { newColor in
                            accentColorManager.saveAccentColor(newColor)
                        }
            } header: {
                Text("APPEARANCE")
            } footer: {
                Text("Choose an accent color for the app. This affects buttons, links, and other interactive elements.")
            }
        }
        .navigationTitle("Alternative UI")
    }
}

#Preview {
    NavigationView {
        AlternativeUIView()
    }
}
