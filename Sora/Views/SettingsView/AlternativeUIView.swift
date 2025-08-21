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
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Use dropdown menu instead of horizontal scroll for seasons")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useSeasonMenu)
                        .tint(Color.accentColor)
                }
            } header: {
                Text("DISPLAY OPTIONS")
            } footer: {
                Text("The alternative season menu uses a dropdown instead of a horizontal scroll for selecting seasons.")
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accent Color")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("This affects buttons, links, and other interactive elements.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    ColorPicker("", selection: $accentColorManager.currentAccentColor)
                        .onChange(of: accentColorManager.currentAccentColor) { newColor in
                            accentColorManager.saveAccentColor(newColor)
                        }
                }
            } header: {
                Text("APPEARANCE")
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
