//
//  HomeView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct HomeView: View {
    @State private var showingSettings = false
    @State private var trendingContent: [TMDBSearchResult] = []
    @State private var popularMovies: [TMDBMovie] = []
    @State private var popularTVShows: [TMDBTVShow] = []
    @State private var popularAnime: [TMDBTVShow] = []
    @State private var topRatedMovies: [TMDBMovie] = []
    @State private var topRatedTVShows: [TMDBTVShow] = []
    @State private var topRatedAnime: [TMDBTVShow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var heroContent: TMDBSearchResult?
    @State private var ambientColor: Color = Color.black
    @AppStorage("useSolidBackgroundBehindHero") private var useSolidBackgroundBehindHero = false
    @State private var hasLoadedContent = false
    
    @AppStorage("homeSections") private var homeSectionsData: Data = {
        if let data = try? JSONEncoder().encode(HomeSection.defaultSections) {
            return data
        }
        return Data()
    }()
    
    private var homeSections: [HomeSection] {
        if let sections = try? JSONDecoder().decode([HomeSection].self, from: homeSectionsData) {
            return sections.sorted { $0.order < $1.order }
        }
        return HomeSection.defaultSections
    }
    
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    
    private let heroHeight: CGFloat = 500
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                homeContent
            }
        } else {
            NavigationView {
                homeContent
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var homeContent: some View {
        ZStack {
            Group {
                if useSolidBackgroundBehindHero {
                    Color.background
                } else {
                    ambientColor
                }
            }
            .ignoresSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else {
                mainScrollView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !hasLoadedContent {
                loadContent()
            }
        }
        .onChange(of: contentFilter.filterHorror) { _, _ in
            if hasLoadedContent {
                loadContent()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading amazing content...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Connection Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                loadContent()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroSection
                contentSections
            }
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }
    
    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            StretchyHeaderView(
                backdropURL: heroContent?.fullBackdropURL ?? heroContent?.fullPosterURL,
                isMovie: heroContent?.isMovie ?? true,
                headerHeight: heroHeight,
                minHeaderHeight: 300,
                onAmbientColorExtracted: { color in
                    ambientColor = color
                }
            )
            
            heroGradientOverlay
            heroContentInfo
        }
    }
    
    @ViewBuilder
    private var heroGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: ambientColor.opacity(0.0), location: 0.0),
                .init(color: ambientColor.opacity(0.4), location: 0.2),
                .init(color: ambientColor.opacity(0.7), location: 0.6),
                .init(color: ambientColor.opacity(1), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    @ViewBuilder
    private var heroContentInfo: some View {
        if let hero = heroContent {
            VStack(alignment: .center, spacing: 12) {
                HStack {
                    Text(hero.isMovie ? "Movie" : "TV Series")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial.opacity(0.9))
                        )
                    
                    if (hero.voteAverage ?? 0.0) > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", hero.voteAverage ?? 0.0))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Capsule())
                    }
                }
                
                Text(hero.displayTitle)
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let overview = hero.overview, !overview.isEmpty {
                    Text(String(overview.prefix(100)) + (overview.count > 100 ? "..." : ""))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                HStack(spacing: 16) {
                    NavigationLink(destination: MediaDetailView(searchResult: hero)) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text("Watch Now")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(width: 140, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial.opacity(0.9))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        // TODO: Add to watchlist
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.subheadline)
                            Text("Watchlist")
                                .fontWeight(.semibold)
                        }
                        .frame(width: 140, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var contentSections: some View {
        VStack(spacing: 0) {
            continueWatchingSection
            
            ForEach(homeSections.filter { $0.isEnabled }) { section in
                switch section.id {
                case "trending":
                    if !trendingContent.isEmpty {
                        let filteredTrending = trendingContent.filter { $0.id != heroContent?.id }
                        MediaSection(
                            title: section.title,
                            items: Array(filteredTrending.prefix(15)),
                            isLarge: true
                        )
                    }
                case "popularMovies":
                    if !popularMovies.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: popularMovies.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "popularTVShows":
                    if !popularTVShows.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: popularTVShows.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "popularAnime":
                    if !popularAnime.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: popularAnime.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "topRatedMovies":
                    if !topRatedMovies.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: topRatedMovies.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "topRatedTVShows":
                    if !topRatedTVShows.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: topRatedTVShows.prefix(15).map { $0.asSearchResult }
                        )
                    }
                case "topRatedAnime":
                    if !topRatedAnime.isEmpty {
                        MediaSection(
                            title: section.title,
                            items: topRatedAnime.prefix(15).map { $0.asSearchResult }
                        )
                    }
                default:
                    EmptyView()
                }
            }
            
            Spacer(minLength: 50)
        }
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var continueWatchingSection: some View {
        EmptyView()
        
        /*
         VStack(alignment: .leading, spacing: 16) {
         HStack {
         Text("ontinue Watching")
         .font(.title2)
         .fontWeight(.bold)
         .foregroundColor(.primary)
         
         Spacer()
         }
         .padding(.horizontal)
         
         ScrollView(.horizontal, showsIndicators: false) {
         LazyHStack(spacing: 12) {
         ForEach(0..<3, id: \.self) { _ in
         ContinueWatchingPlaceholder()
         }
         }
         .padding(.horizontal)
         }
         }
         .padding(.vertical, 24)
         */
    }
    
    private func loadContent() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                async let trending = tmdbService.getTrending()
                async let popularM = tmdbService.getPopularMovies()
                async let popularTV = tmdbService.getPopularTVShows()
                async let popularA = tmdbService.getPopularAnime()
                async let topRatedM = tmdbService.getTopRatedMovies()
                async let topRatedTV = tmdbService.getTopRatedTVShows()
                async let topRatedA = tmdbService.getTopRatedAnime()
                
                let (trendingResult, popularMoviesResult, popularTVResult, popularAnimeResult, topRatedMoviesResult, topRatedTVResult, topRatedAnimeResult) = try await (trending, popularM, popularTV, popularA, topRatedM, topRatedTV, topRatedA)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        // Apply content filtering
                        self.trendingContent = contentFilter.filterSearchResults(trendingResult)
                        self.popularMovies = contentFilter.filterMovies(popularMoviesResult)
                        self.popularTVShows = contentFilter.filterTVShows(popularTVResult)
                        self.popularAnime = contentFilter.filterTVShows(popularAnimeResult)
                        self.topRatedMovies = contentFilter.filterMovies(topRatedMoviesResult)
                        self.topRatedTVShows = contentFilter.filterTVShows(topRatedTVResult)
                        self.topRatedAnime = contentFilter.filterTVShows(topRatedAnimeResult)
                        
                        self.heroContent = self.trendingContent.first { $0.backdropPath != nil } ?? self.trendingContent.first
                        self.isLoading = false
                        self.hasLoadedContent = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    Logger.shared.log("Error loading content: \(error)", type: "Error")
                }
            }
        }
    }
}

struct MediaSection: View {
    let title: String
    let items: [TMDBSearchResult]
    let isLarge: Bool
    
    init(title: String, items: [TMDBSearchResult], isLarge: Bool = false) {
        self.title = title
        self.items = items
        self.isLarge = isLarge
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: isLarge ? 20 : 10) {
                    ForEach(items) { item in
                        if isLarge {
                            FeaturedCard(result: item, isLarge: true)
                        } else {
                            MediaCard(result: item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 24)
        .opacity(items.isEmpty ? 0 : 1)
    }
}

struct MediaCard: View {
    let result: TMDBSearchResult
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)) {
            VStack(alignment: .leading, spacing: 6) {
                KFImage(URL(string: result.fullPosterURL ?? ""))
                    .placeholder {
                        FallbackImageView(
                            isMovie: result.isMovie,
                            size: CGSize(width: 120, height: 180)
                        )
                    }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.displayTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.white)
                    
                    HStack(alignment: .center,spacing: 3) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", result.voteAverage ?? 0.0))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text(result.isMovie ? "Movie" : "TV")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial.opacity(0.9))
                            )
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContinueWatchingPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 120)
                
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue Watching")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Feature coming soon...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, alignment: .leading)
        }
    }
}
