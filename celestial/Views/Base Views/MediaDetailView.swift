//
//  MediaDetailView.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

struct MediaDetailView: View {
    let searchResult: TMDBSearchResult
    
    @StateObject private var tmdbService = TMDBService.shared
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvShowDetail: TMDBTVShowWithSeasons?
    @State private var selectedSeason: TMDBSeason?
    @State private var seasonDetail: TMDBSeasonDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    private let headerHeight: CGFloat = 450
    private let minHeaderHeight: CGFloat = 300
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Error")
                        .font(.title2)
                        .padding(.top)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        loadMediaDetails()
                    }
                    .padding(.top)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ZStack(alignment: .bottom) {
                            StretchyHeaderView(
                                backdropURL: searchResult.isMovie ? movieDetail?.fullBackdropURL : tvShowDetail?.fullBackdropURL,
                                isMovie: searchResult.isMovie,
                                headerHeight: headerHeight,
                                minHeaderHeight: minHeaderHeight
                            )
                            
                            Text(searchResult.displayTitle)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(3)
                        }
                        
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 16) {
                                if let overview = searchResult.isMovie ? movieDetail?.overview : tvShowDetail?.overview,
                                   !overview.isEmpty {
                                    Text("Overview")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text(overview)
                                        .font(.body)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Button(action: {
                                    // TODO: Implement play functionality
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Play")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal)
                            
                            if searchResult.isMovie {
                                MovieDetailsSection(movie: movieDetail)
                            } else {
                                TVShowSeasonsSection(
                                    tvShow: tvShowDetail,
                                    selectedSeason: $selectedSeason,
                                    seasonDetail: $seasonDetail,
                                    tmdbService: tmdbService
                                )
                            }
                            
                            Spacer(minLength: 50)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadMediaDetails()
        }
        .overlay(
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
        )
    }
    
    private func loadMediaDetails() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if searchResult.isMovie {
                    let detail = try await tmdbService.getMovieDetails(id: searchResult.id)
                    await MainActor.run {
                        self.movieDetail = detail
                        self.isLoading = false
                    }
                } else {
                    let detail = try await tmdbService.getTVShowWithSeasons(id: searchResult.id)
                    await MainActor.run {
                        self.tvShowDetail = detail
                        if let firstSeason = detail.seasons.first(where: { $0.seasonNumber > 0 }) {
                            self.selectedSeason = firstSeason
                        }
                        self.isLoading = false
                    }
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

// MARK: - Stretchy Header View
struct StretchyHeaderView: View {
    let backdropURL: String?
    let isMovie: Bool
    let headerHeight: CGFloat
    let minHeaderHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let deltaY = frame.minY
            let height = headerHeight + max(0, deltaY)
            let offset = min(0, -deltaY)
            
            ZStack(alignment: .bottom) {
                Color.clear
                    .overlay(
                        KFImage(URL(string: backdropURL ?? ""))
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill),
                        alignment: .center
                    )
                    .clipped()
                    .frame(height: height)
                    .offset(y: offset)
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)
                .offset(y: offset)
            }
        }
        .frame(height: headerHeight)
    }
}

// MARK: - Movie Details Section
struct MovieDetailsSection: View {
    let movie: TMDBMovieDetail?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let movie = movie {
                Text("Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    if let runtime = movie.runtime, runtime > 0 {
                        DetailRow(title: "Runtime", value: movie.runtimeFormatted)
                    }
                    
                    if !movie.genres.isEmpty {
                        DetailRow(title: "Genres", value: movie.genres.map { $0.name }.joined(separator: ", "))
                    }
                    
                    if movie.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", movie.voteAverage))
                    }
                    
                    if let tagline = movie.tagline, !tagline.isEmpty {
                        DetailRow(title: "Tagline", value: tagline)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - TV Show Seasons Section
struct TVShowSeasonsSection: View {
    let tvShow: TMDBTVShowWithSeasons?
    @Binding var selectedSeason: TMDBSeason?
    @Binding var seasonDetail: TMDBSeasonDetail?
    let tmdbService: TMDBService
    
    @State private var isLoadingSeason = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let tvShow = tvShow {
                Text("Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    if let numberOfSeasons = tvShow.numberOfSeasons, numberOfSeasons > 0 {
                        DetailRow(title: "Seasons", value: "\(numberOfSeasons)")
                    }
                    
                    if let numberOfEpisodes = tvShow.numberOfEpisodes, numberOfEpisodes > 0 {
                        DetailRow(title: "Episodes", value: "\(numberOfEpisodes)")
                    }
                    
                    if !tvShow.genres.isEmpty {
                        DetailRow(title: "Genres", value: tvShow.genres.map { $0.name }.joined(separator: ", "))
                    }
                    
                    if tvShow.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", tvShow.voteAverage))
                    }
                    
                    if let status = tvShow.status {
                        DetailRow(title: "Status", value: status)
                    }
                }
                .padding(.horizontal)
                
                if !tvShow.seasons.isEmpty {
                    Text("Seasons")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(tvShow.seasons.filter { $0.seasonNumber > 0 }) { season in
                                Button(action: {
                                    selectedSeason = season
                                    loadSeasonDetails(tvShowId: tvShow.id, season: season)
                                }) {
                                    VStack(spacing: 8) {
                                        KFImage(URL(string: season.fullPosterURL ?? ""))
                                            .placeholder {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 80, height: 120)
                                                    .overlay(
                                                        VStack {
                                                            Image(systemName: "tv")
                                                                .font(.title2)
                                                                .foregroundColor(.white.opacity(0.7))
                                                            Text("S\(season.seasonNumber)")
                                                                .font(.caption)
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.white.opacity(0.7))
                                                        }
                                                    )
                                            }
                                            .resizable()
                                            .aspectRatio(2/3, contentMode: .fill)
                                            .frame(width: 80, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedSeason?.id == season.id ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                        
                                        Text(season.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 80)
                                            .foregroundColor(selectedSeason?.id == season.id ? .blue : .primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if let seasonDetail = seasonDetail {
                        Text("Episodes")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(seasonDetail.episodes) { episode in
                                EpisodeCard(episode: episode)
                            }
                        }
                        .padding(.horizontal)
                    } else if isLoadingSeason {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading episodes...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
        }
        .onAppear {
            if let tvShow = tvShow, let selectedSeason = selectedSeason {
                loadSeasonDetails(tvShowId: tvShow.id, season: selectedSeason)
            }
        }
    }
    
    private func loadSeasonDetails(tvShowId: Int, season: TMDBSeason) {
        isLoadingSeason = true
        
        Task {
            do {
                let detail = try await tmdbService.getSeasonDetails(tvShowId: tvShowId, seasonNumber: season.seasonNumber)
                await MainActor.run {
                    self.seasonDetail = detail
                    self.isLoadingSeason = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSeason = false
                }
            }
        }
    }
}

// MARK: - Episode Card
struct EpisodeCard: View {
    let episode: TMDBEpisode
    @State private var progress: Double = 0.0
    @State private var isWatched: Bool = false
    
    private var episodeKey: String {
        "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
    }
    
    var body: some View {
        Button(action: {
            // TODO: Implement play episode functionality
            print("Playing episode \(episode.episodeNumber): \(episode.name)")
        }) {
            HStack(spacing: 12) {
                ZStack {
                    KFImage(URL(string: episode.fullStillURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                )
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .opacity(0.8)
                    
                    if progress > 0 && progress < 0.95 {
                        VStack {
                            Spacer()
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(height: 3)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 4)
                        }
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    if isWatched || progress >= 0.95 {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                            Spacer()
                        }
                        .frame(width: 120, height: 68)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        
                        if !episode.name.isEmpty {
                            Text(episode.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        } else {
                            Text("Episode \(episode.episodeNumber)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        if let runtime = episode.runtime, runtime > 0 {
                            Text(episode.runtimeFormatted)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    HStack {
                        if episode.voteAverage > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", episode.voteAverage))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if progress > 0 {
                            CircularProgressBar(progress: progress, size: 24, lineWidth: 2.5)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            episodeContextMenu
        }
        .onAppear {
            loadEpisodeProgress()
        }
    }
    
    private var episodeContextMenu: some View {
        Group {
            Button(action: {
                // TODO: Implement play functionality
                print("Play episode \(episode.episodeNumber)")
            }) {
                Label("Play", systemImage: "play.fill")
            }
            
            if progress > 0 && progress < 0.95 {
                Button(action: markAsWatched) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress > 0 {
                Button(action: resetProgress) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
    
    private func loadEpisodeProgress() {
        let savedProgress = UserDefaults.standard.double(forKey: "progress_\(episodeKey)")
        let savedWatched = UserDefaults.standard.bool(forKey: "watched_\(episodeKey)")
        
        progress = savedProgress
        isWatched = savedWatched || savedProgress >= 0.95
    }
    
    private func markAsWatched() {
        progress = 1.0
        isWatched = true
        UserDefaults.standard.set(1.0, forKey: "progress_\(episodeKey)")
        UserDefaults.standard.set(true, forKey: "watched_\(episodeKey)")
    }
    
    private func resetProgress() {
        progress = 0.0
        isWatched = false
        UserDefaults.standard.set(0.0, forKey: "progress_\(episodeKey)")
        UserDefaults.standard.set(false, forKey: "watched_\(episodeKey)")
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
