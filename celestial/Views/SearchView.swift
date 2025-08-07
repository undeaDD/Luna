//
//  SearchView.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchFilter: SearchFilter = .all
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    
    @StateObject private var tmdbService = TMDBService.shared
    
    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"
    }
    
    var filteredResults: [TMDBSearchResult] {
        switch searchFilter {
        case .all:
            return searchResults
        case .movies:
            return searchResults.filter { $0.isMovie }
        case .tvShows:
            return searchResults.filter { $0.isTVShow }
        }
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                searchContent
            }
        } else {
            NavigationView {
                searchContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var searchContent: some View {
        VStack(spacing: 0) {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search movies and TV shows...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                searchResults = []
                                errorMessage = nil
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            searchResults = []
                            errorMessage = nil
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                if !searchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SearchFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    searchFilter = filter
                                }) {
                                    Text(filter.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(searchFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(searchFilter == filter ? .white : .primary)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Error")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(.top)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        performSearch()
                    }
                    .padding(.top)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass.circle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Search Movies & TV Shows")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Find your favorite movies and TV shows from The Movie Database")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredResults.isEmpty && !searchResults.isEmpty {
                VStack {
                    Image(systemName: "tv.and.hifispeaker.fill")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No \(searchFilter.rawValue.lowercased()) found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Try adjusting your filter or search for something else")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack {
                    Image(systemName: "questionmark.circle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No results found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("Try searching for a different movie or TV show")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 16
                    ) {
                        ForEach(filteredResults) { result in
                            SearchResultCard(result: result)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
            }
        }
        .navigationTitle("Search")
        .onChange(of: selectedLanguage) { _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await tmdbService.searchMulti(query: searchText)
                
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    SearchView()
}
