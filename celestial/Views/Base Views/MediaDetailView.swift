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
    @State private var ambientColor: Color = Color.black
    @State private var showFullSynopsis: Bool = false
    @State private var selectedEpisodeNumber: Int = 0
    @State private var selectedSeasonIndex: Int = 0
    @State private var synopsis: String = ""
    @State private var isBookmarked: Bool = false
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private let headerHeight: CGFloat = 550
    private let minHeaderHeight: CGFloat = 400
    
    private var isCompactLayout: Bool {
        return verticalSizeClass == .compact
    }
    
    var body: some View {
        ZStack {
            ambientColor
                .ignoresSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else {
                mainScrollView
            }
            
            navigationOverlay
        }
        .navigationBarHidden(true)
        .onAppear {
            loadMediaDetails()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .padding(.top)
            
            Text(message)
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
    }
    
    @ViewBuilder
    private var navigationOverlay: some View {
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
                
                Button(action: {
                    // TODO: Add menu functionality
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroImageSection
                contentContainer
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    @ViewBuilder
    private var heroImageSection: some View {
        ZStack(alignment: .bottom) {
            StretchyHeaderView(
                backdropURL: searchResult.isMovie ? movieDetail?.fullBackdropURL : tvShowDetail?.fullBackdropURL,
                isMovie: searchResult.isMovie,
                headerHeight: headerHeight,
                minHeaderHeight: minHeaderHeight,
                onAmbientColorExtracted: { color in
                    withAnimation(.easeInOut(duration: 0.8)) {
                        ambientColor = color
                    }
                }
            )
            
            gradientOverlay
            
            headerSection
        }
    }
    
    @ViewBuilder
    private var contentContainer: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                synopsisSection
                playAndBookmarkSection
                
                if searchResult.isMovie {
                    MovieDetailsSection(movie: movieDetail)
                } else {
                    episodesSection
                }
                
                Spacer(minLength: 50)
            }
            .background(Color.clear)
        }
    }
    
    @ViewBuilder
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: ambientColor.opacity(0.0), location: 0.0),
                .init(color: ambientColor.opacity(0.4), location: 0.2),
                .init(color: ambientColor.opacity(0.6), location: 0.5),
                .init(color: ambientColor.opacity(1), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .animation(.easeInOut(duration: 0.8), value: ambientColor)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(searchResult.displayTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 40)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !synopsis.isEmpty {
                Text(showFullSynopsis ? synopsis : String(synopsis.prefix(180)) + (synopsis.count > 180 ? "..." : ""))
                    .font(.body)
                    .lineLimit(showFullSynopsis ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFullSynopsis.toggle()
                        }
                    }
            } else if let overview = searchResult.isMovie ? movieDetail?.overview : tvShowDetail?.overview,
                      !overview.isEmpty {
                Text(showFullSynopsis ? overview : String(overview.prefix(200)) + (overview.count > 200 ? "..." : ""))
                    .font(.body)
                    .lineLimit(showFullSynopsis ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFullSynopsis.toggle()
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var playAndBookmarkSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                // TODO: Implement play functionality
                print("Play button tapped")
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Play")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 25)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                )
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            
            Button(action: {
                toggleBookmark()
            }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                    .foregroundColor(isBookmarked ? .yellow : .primary)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        if !searchResult.isMovie {
            TVShowSeasonsSection(
                tvShow: tvShowDetail,
                selectedSeason: $selectedSeason,
                seasonDetail: $seasonDetail,
                tmdbService: tmdbService
            )
        }
    }
    
    private func toggleBookmark() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isBookmarked.toggle()
        }
        // TODO: Implement actual bookmark functionality
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
                        self.synopsis = detail.overview ?? ""
                        self.isLoading = false
                    }
                } else {
                    let detail = try await tmdbService.getTVShowWithSeasons(id: searchResult.id)
                    await MainActor.run {
                        self.tvShowDetail = detail
                        self.synopsis = detail.overview ?? ""
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
    let onAmbientColorExtracted: ((Color) -> Void)?
    
    @State private var localAmbientColor: Color = Color.black
    @State private var backdropImage: UIImage?
    
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
                            .onSuccess { result in
                                backdropImage = result.image
                                let extractedColor = Color.ambientColor(from: result.image)
                                localAmbientColor = extractedColor
                                onAmbientColorExtracted?(extractedColor)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill),
                        alignment: .center
                    )
                    .clipped()
                    .frame(height: height)
                    .offset(y: offset)
                
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: localAmbientColor.opacity(0.0), location: 0.0),
                        .init(color: localAmbientColor.opacity(0.1), location: 0.2),
                        .init(color: localAmbientColor.opacity(0.3), location: 0.7),
                        .init(color: localAmbientColor.opacity(0.6), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .animation(.easeInOut(duration: 0.8), value: localAmbientColor)
            }
        }
        .frame(height: headerHeight)
        .onAppear {
            if let backdropURL = backdropURL, let url = URL(string: backdropURL) {
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    case .success(let value):
                        backdropImage = value.image
                        let extractedColor = Color.ambientColor(from: value.image)
                        localAmbientColor = extractedColor
                        onAmbientColorExtracted?(extractedColor)
                    case .failure:
                        break
                    }
                }
            }
        }
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
                    
                    if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                        DetailRow(title: "Release Date", value: releaseDate)
                    }
                    
                    if movie.voteAverage > 0 {
                        DetailRow(title: "Rating", value: String(format: "%.1f/10", movie.voteAverage))
                    }
                    
                    if let tagline = movie.tagline, !tagline.isEmpty {
                        DetailRow(title: "Tagline", value: tagline)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                )
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
    
    private var isGroupedBySeasons: Bool {
        return tvShow?.seasons.filter { $0.seasonNumber > 0 }.count ?? 0 > 1
    }
    
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
                    
                    if let firstAirDate = tvShow.firstAirDate, !firstAirDate.isEmpty {
                        DetailRow(title: "First aired", value: "\(firstAirDate)")
                    }
                    
                    if let lastAirDate = tvShow.lastAirDate, !lastAirDate.isEmpty {
                        DetailRow(title: "Last aired", value: "\(lastAirDate)")
                    }
                    
                    if let status = tvShow.status {
                        DetailRow(title: "Status", value: status)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                )
                .padding(.horizontal)
                
                if !tvShow.seasons.isEmpty {
                    episodesSectionHeader
                    
                    if isGroupedBySeasons {
                        seasonSelectorStyled
                    }
                    
                    episodeListSection
                }
            }
        }
        .onAppear {
            if let tvShow = tvShow, let selectedSeason = selectedSeason {
                loadSeasonDetails(tvShowId: tvShow.id, season: selectedSeason)
            }
        }
    }
    
    @ViewBuilder
    private var episodesSectionHeader: some View {
        HStack {
            Text("Episodes")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    @ViewBuilder
    private var seasonSelectorStyled: some View {
        if let tvShow = tvShow {
            let seasons = tvShow.seasons.filter { $0.seasonNumber > 0 }
            if seasons.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(seasons) { season in
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
            }
        }
    }
    
    @ViewBuilder
    private var episodeListSection: some View {
        Group {
            if let seasonDetail = seasonDetail {
                LazyVStack(spacing: 15) {
                    ForEach(Array(seasonDetail.episodes.enumerated()), id: \.element.id) { index, episode in
                        createEpisodeCell(episode: episode, index: index)
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
    
    @ViewBuilder
    private func createEpisodeCell(episode: TMDBEpisode, index: Int) -> some View {
        let episodeKey = "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episodeKey)")
        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episodeKey)")
        let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
        
        EpisodeCell(
            episode: episode,
            progress: progress,
            onTap: { episodeTapAction(episode: episode) },
            onMarkWatched: { markAsWatched(episode: episode) },
            onResetProgress: { resetProgress(episode: episode) }
        )
    }
    
    private func episodeTapAction(episode: TMDBEpisode) {
        // TODO: Implement episode tap functionality
        print("Playing episode \(episode.episodeNumber): \(episode.name)")
    }
    
    private func markAsWatched(episode: TMDBEpisode) {
        let episodeKey = "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
        UserDefaults.standard.set(1.0, forKey: "lastPlayedTime_\(episodeKey)")
        UserDefaults.standard.set(1.0, forKey: "totalTime_\(episodeKey)")
    }
    
    private func resetProgress(episode: TMDBEpisode) {
        let episodeKey = "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
        UserDefaults.standard.set(0.0, forKey: "lastPlayedTime_\(episodeKey)")
        UserDefaults.standard.set(0.0, forKey: "totalTime_\(episodeKey)")
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

// MARK: - Episode Cell
struct EpisodeCell: View {
    let episode: TMDBEpisode
    let progress: Double
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onResetProgress: () -> Void
    
    @State private var isWatched: Bool = false
    
    private var episodeKey: String {
        "episode_\(episode.seasonNumber)_\(episode.episodeNumber)"
    }
    
    var body: some View {
        Button(action: onTap) {
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
                        Text("Episode \(episode.episodeNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        
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
                    
                    if !episode.name.isEmpty {
                        Text(episode.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
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
                    .fill(Color.black.opacity(0.2))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
            Button(action: onTap) {
                Label("Play", systemImage: "play.fill")
            }
            
            if progress > 0 && progress < 0.95 {
                Button(action: {
                    onMarkWatched()
                    isWatched = true
                }) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress > 0 {
                Button(action: {
                    onResetProgress()
                    isWatched = false
                }) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
    
    private func loadEpisodeProgress() {
        let savedProgress = UserDefaults.standard.double(forKey: "progress_\(episodeKey)")
        let savedWatched = UserDefaults.standard.bool(forKey: "watched_\(episodeKey)")
        
        isWatched = savedWatched || progress >= 0.95
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
