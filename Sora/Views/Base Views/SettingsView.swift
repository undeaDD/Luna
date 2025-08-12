//
//  SettingsView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    @Environment(\.dismiss) private var dismiss
    
    let languages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("ru-RU", "Russian"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
        ("th-TH", "Thai"),
        ("tr-TR", "Turkish"),
        ("pl-PL", "Polish"),
        ("nl-NL", "Dutch"),
        ("sv-SE", "Swedish"),
        ("da-DK", "Danish"),
        ("no-NO", "Norwegian"),
        ("fi-FI", "Finnish")
    ]
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                settingsContent
            }
        } else {
            NavigationView {
                settingsContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var settingsContent: some View {
        List {
            Section {
                NavigationLink(destination: LanguageSelectionView(selectedLanguage: $selectedLanguage, languages: languages)) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Informations Language")
                        }
                        
                        Spacer()
                        
                        Text(languages.first { $0.0 == selectedLanguage }?.1 ?? "English (US)")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("TMDB Settings")
            } footer: {
                Text("This setting affects the language of movie titles, descriptions, and other content from TMDB.")
            }
            
            Section {
                NavigationLink(destination: LoggerView()) {
                    Text("Logger")
                }
            }
        }
        .navigationTitle("Settings")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: String
    let languages: [(String, String)]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(languages, id: \.0) { language in
                HStack {
                    Text(language.1)
                    Spacer()
                    if selectedLanguage == language.0 {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedLanguage = language.0
                    dismiss()
                }
            }
        }
        .navigationTitle("Language")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Celestial")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Celestial")
                        .font(.headline)
                    
                    Text("Celestial is a modern movie and TV show discovery app that helps you find and explore content from The Movie Database (TMDB). Discover new favorites, keep track of what you want to watch, and explore detailed information about movies and TV shows.")
                        .font(.body)
                    
                    Text("Features")
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "magnifyingglass", text: "Search movies and TV shows")
                        FeatureRow(icon: "books.vertical", text: "Personal library management")
                        FeatureRow(icon: "globe", text: "Multi-language support")
                        FeatureRow(icon: "star", text: "Ratings and reviews")
                    }
                    
                    Text("Data Source")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("This app uses The Movie Database (TMDB) API to provide movie and TV show information. TMDB is a community-built movie and TV database.")
                        .font(.body)
                    
                    Link("Visit TMDB", destination: URL(string: "https://www.themoviedb.org")!)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("About")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
