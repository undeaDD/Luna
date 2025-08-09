//
//  SearchView.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct SearchView: View {
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 3
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 5
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    
    @State private var searchText = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchFilter: SearchFilter = .all
    @State private var showServiceDownloadAlert = false
    @State private var serviceDownloadError: String?
    
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var serviceManager = ServiceManager.shared
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
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
    
    var filterIcon: String {
        switch searchFilter {
        case .all:
            return "square.grid.2x2"
        case .movies:
            return "tv"
        case .tvShows:
            return "tv.fill"
        }
    }
    
    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
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
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Search...", text: $searchText)
                            .padding(7)
                            .padding(.horizontal, 25)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                    
                                    if !searchText.isEmpty {
                                        Button(action: {
                                            searchText = ""
                                            searchResults = []
                                            errorMessage = nil
                                        }) {
                                            Image(systemName: "multiply.circle.fill")
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 8)
                                        }
                                    }
                                }
                            )
                            .onSubmit {
                                performSearchOrDownloadService()
                            }
                            .onChange(of: searchText) { newValue in
                                if newValue.isEmpty {
                                    searchResults = []
                                    errorMessage = nil
                                }
                            }
                    }
                    
                    if !searchResults.isEmpty {
                        Menu {
                            ForEach(SearchFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    searchFilter = filter
                                }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if searchFilter == filter {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: searchFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: searchResults.isEmpty)
            }
            .padding()
            
            if isLoading || serviceManager.isDownloading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    if serviceManager.isDownloading {
                        VStack(spacing: 8) {
                            Text(serviceManager.downloadMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: serviceManager.downloadProgress)
                                .frame(width: 200)
                        }
                        .padding(.top, 8)
                    } else {
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
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
                        performSearchOrDownloadService()
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
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
        .alert("Service Downloaded", isPresented: $showServiceDownloadAlert) {
            Button("OK") { }
        } message: {
            Text("The service has been successfully downloaded and saved to your documents folder.")
        }
        .alert("Download Error", isPresented: .constant(serviceDownloadError != nil)) {
            Button("OK") { 
                serviceDownloadError = nil
            }
        } message: {
            Text(serviceDownloadError ?? "")
        }
        .onChange(of: selectedLanguage) { _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch()
            }
        }
    }
    
    
    private func performSearchOrDownloadService() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Check if the input is a JSON URL for service download
        if isJSONURL(searchText) {
            downloadServiceFromURL()
        } else {
            performSearch()
        }
    }
    
    private func isJSONURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        
        return url.scheme != nil && 
        (url.pathExtension.lowercased() == "json" || 
         text.lowercased().contains(".json"))
    }
    
    private func downloadServiceFromURL() {
        Task {
            do {
                let wasHandled = await serviceManager.handlePotentialServiceURL(searchText)
                if wasHandled {
                    await MainActor.run {
                        searchText = ""
                        showServiceDownloadAlert = true
                    }
                }
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
