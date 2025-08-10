//
//  ModulesSearchResultsSheet.swift
//  celestial
//
//  Created by Francesco on 09/08/25.
//

import AVKit
import UIKit
import SwiftUI
import Kingfisher

struct ModulesSearchResultsSheet: View {
    let mediaTitle: String
    let isMovie: Bool
    let selectedEpisode: TMDBEpisode?
    
    @Environment(\.presentationMode) var presentationMode
    @State private var moduleResults: [(service: Services, results: [SearchItem])] = []
    @State private var selectedResult: SearchItem?
    @State private var showingPlayAlert = false
    @State private var expandedServices: Set<UUID> = []
    @State private var isSearching = true
    @State private var searchedServices: Set<UUID> = []
    @State private var totalServicesCount = 0
    @State private var player: AVPlayer?
    @State private var playerViewController: NormalPlayer?
    
    @StateObject private var serviceManager = ServiceManager.shared
    
    private var servicesWithResults: [(service: Services, results: [SearchItem])] {
        moduleResults.filter { !$0.results.isEmpty }
    }
    
    private func filterResults(for results: [SearchItem]) -> (highQuality: [SearchItem], lowQuality: [SearchItem]) {
        let sortedResults = results.map { result in
            (result: result, similarity: calculateSimilarity(original: mediaTitle, result: result.title))
        }.sorted { $0.similarity > $1.similarity }
        
        let highQuality = sortedResults.filter { $0.similarity >= 0.75 }.map { $0.result }
        let lowQuality = sortedResults.filter { $0.similarity < 0.75 }.map { $0.result }
        
        return (highQuality, lowQuality)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Searching for:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let episode = selectedEpisode {
                            Text("\(mediaTitle) S\(episode.seasonNumber)E\(episode.episodeNumber)")
                                .font(.headline)
                                .fontWeight(.semibold)
                        } else {
                            Text(mediaTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        if let episode = selectedEpisode {
                            HStack {
                                if !episode.name.isEmpty {
                                    Text(episode.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("S\(episode.seasonNumber)E\(episode.episodeNumber)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        
                        HStack {
                            Text(isMovie ? "Movie" : "TV Show")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isMovie ? Color.purple.opacity(0.2) : Color.green.opacity(0.2))
                                .foregroundColor(isMovie ? .purple : .green)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            if isSearching {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Searching... (\(searchedServices.count)/\(totalServicesCount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Search complete")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if serviceManager.activeServices.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("No Active Services")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("You don't have any active services. Please go to the Services tab to download and activate services.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(serviceManager.activeServices, id: \.id) { service in
                        let moduleResult = moduleResults.first { $0.service.id == service.id }
                        let hasSearched = searchedServices.contains(service.id)
                        let isCurrentlySearching = isSearching && !hasSearched
                        
                        if let result = moduleResult {
                            let filteredResults = filterResults(for: result.results)
                            
                            Section(header: serviceHeader(for: service, highQualityCount: filteredResults.highQuality.count, lowQualityCount: filteredResults.lowQuality.count, isSearching: false)) {
                                if result.results.isEmpty {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text("No results found")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                } else {
                                    ForEach(filteredResults.highQuality, id: \.id) { searchResult in
                                        EnhancedMediaResultRow(
                                            result: searchResult,
                                            originalTitle: mediaTitle,
                                            episode: selectedEpisode,
                                            onTap: {
                                                selectedResult = searchResult
                                                showingPlayAlert = true
                                            }
                                        )
                                    }
                                    
                                    if !filteredResults.lowQuality.isEmpty {
                                        let isExpanded = expandedServices.contains(service.id)
                                        
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                if isExpanded {
                                                    expandedServices.remove(service.id)
                                                } else {
                                                    expandedServices.insert(service.id)
                                                }
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "questionmark.circle")
                                                    .foregroundColor(.orange)
                                                
                                                Text("\(filteredResults.lowQuality.count) lower match result\(filteredResults.lowQuality.count == 1 ? "" : "s")")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if isExpanded {
                                            ForEach(filteredResults.lowQuality, id: \.id) { searchResult in
                                                CompactMediaResultRow(
                                                    result: searchResult,
                                                    originalTitle: mediaTitle,
                                                    episode: selectedEpisode,
                                                    onTap: {
                                                        selectedResult = searchResult
                                                        showingPlayAlert = true
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        } else if isCurrentlySearching {
                            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: true)) {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Searching...")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        } else if !isSearching && !hasSearched {
                            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: false)) {
                                HStack {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.gray)
                                    Text("Not searched")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Results")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert("Play Content", isPresented: $showingPlayAlert) {
            Button("Play") {
                showingPlayAlert = false
                if let result = selectedResult {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        playContent(result)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                selectedResult = nil
            }
        } message: {
            if let result = selectedResult, let episode = selectedEpisode {
                Text("Play Episode \(episode.episodeNumber) of '\(result.title)'?")
            } else if let result = selectedResult {
                Text("Play '\(result.title)'?")
            }
        }
        .onAppear {
            startProgressiveSearch()
        }
    }
    
    private func startProgressiveSearch() {
        let activeServices = serviceManager.activeServices
        totalServicesCount = activeServices.count
        
        guard !activeServices.isEmpty else {
            isSearching = false
            return
        }
        
        let searchQuery: String
        if let episode = selectedEpisode {
            searchQuery = "\(mediaTitle) S\(episode.seasonNumber)E\(episode.episodeNumber)"
        } else {
            searchQuery = mediaTitle
        }
        
        Task {
            await serviceManager.searchInActiveServicesProgressively(
                query: searchQuery,
                onResult: { service, results in
                    Task { @MainActor in
                        if let existingIndex = moduleResults.firstIndex(where: { $0.service.id == service.id }) {
                            moduleResults[existingIndex] = (service: service, results: results)
                        } else {
                            moduleResults.append((service: service, results: results))
                        }
                        
                        searchedServices.insert(service.id)
                    }
                },
                onComplete: {
                    Task { @MainActor in
                        isSearching = false
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private func serviceHeader(for service: Services, highQualityCount: Int, lowQualityCount: Int, isSearching: Bool = false) -> some View {
        HStack {
            KFImage(URL(string: service.metadata.iconUrl))
                .placeholder {
                    Image(systemName: "tv.circle")
                        .foregroundColor(.secondary)
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            
            Text(service.metadata.sourceName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            HStack(spacing: 4) {
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    if highQualityCount > 0 {
                        Text("\(highQualityCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    if lowQualityCount > 0 {
                        Text("\(lowQualityCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func getResultCount(for service: Services) -> Int {
        return moduleResults.first { $0.service.id == service.id }?.results.count ?? 0
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return LevenshteinDistance.calculateSimilarity(original: original, result: result)
    }
    
    private func playContent(_ result: SearchItem) {
        Logger.shared.log("Starting playback for: \(result.title)", type: "Stream")
        
        guard let service = serviceManager.activeServices.first(where: { service in
            moduleResults.contains { $0.service.id == service.id && $0.results.contains { $0.id == result.id } }
        }) else {
            Logger.shared.log("Could not find service for result: \(result.title)", type: "Error")
            return
        }
        
        Logger.shared.log("Using service: \(service.metadata.sourceName)", type: "Stream")
        
        let jsController = JSController()
        let servicePath = serviceManager.servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        Logger.shared.log("JavaScript path: \(jsPath.path)", type: "Stream")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "Error")
            return
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            jsController.loadScript(jsContent)
            Logger.shared.log("JavaScript loaded successfully", type: "Stream")
        } catch {
            Logger.shared.log("Failed to load JavaScript for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "Error")
            return
        }
        
        jsController.fetchEpisodesJS(url: result.href) { episodes in
            DispatchQueue.main.async {
                Logger.shared.log("Fetched \(episodes.count) episodes for: \(result.title)", type: "Stream")
                
                if episodes.isEmpty {
                    Logger.shared.log("No episodes found for: \(result.title)", type: "Error")
                    return
                }
                
                let targetHref: String
                
                if self.isMovie {
                    targetHref = episodes.first?.href ?? result.href
                    Logger.shared.log("Movie - Using href: \(targetHref)", type: "Stream")
                } else {
                    guard let selectedEpisode = self.selectedEpisode else {
                        Logger.shared.log("No episode selected for TV show", type: "Error")
                        return
                    }
                    
                    var seasons: [[EpisodeLink]] = []
                    var currentSeason: [EpisodeLink] = []
                    var lastEpisodeNumber = 0
                    
                    for episode in episodes {
                        if episode.number == 1 || episode.number <= lastEpisodeNumber {
                            if !currentSeason.isEmpty {
                                seasons.append(currentSeason)
                                currentSeason = []
                            }
                        }
                        currentSeason.append(episode)
                        lastEpisodeNumber = episode.number
                    }
                    
                    if !currentSeason.isEmpty {
                        seasons.append(currentSeason)
                    }
                    
                    let targetSeasonIndex = selectedEpisode.seasonNumber - 1
                    let targetEpisodeNumber = selectedEpisode.episodeNumber
                    
                    guard targetSeasonIndex >= 0 && targetSeasonIndex < seasons.count else {
                        Logger.shared.log("Season \(selectedEpisode.seasonNumber) not found. Available seasons: \(seasons.count)", type: "Error")
                        return
                    }
                    
                    let season = seasons[targetSeasonIndex]
                    guard let targetEpisode = season.first(where: { $0.number == targetEpisodeNumber }) else {
                        Logger.shared.log("Episode \(targetEpisodeNumber) not found in season \(selectedEpisode.seasonNumber). Available episodes: \(season.map { $0.number })", type: "Error")
                        return
                    }
                    
                    targetHref = targetEpisode.href
                    Logger.shared.log("TV Show - S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber) - Using href: \(targetHref)", type: "Stream")
                }
                
                jsController.fetchStreamUrlJS(episodeUrl: targetHref, module: service) { streamResult in
                    DispatchQueue.main.async {
                        let (streams, subtitles, sources) = streamResult
                        
                        Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
                        
                        var streamURL: URL?
                        
                        if let streams = streams, !streams.isEmpty {
                            Logger.shared.log("Found \(streams.count) stream(s) for \(result.title)", type: "Stream")
                            Logger.shared.log("First stream URL: \(streams.first!)", type: "Stream")
                            streamURL = URL(string: streams.first!)
                        } else if let sources = sources, !sources.isEmpty {
                            Logger.shared.log("Found \(sources.count) source(s) with headers for \(result.title)", type: "Stream")
                            if let firstSource = sources.first,
                               let urlString = firstSource["url"] as? String {
                                Logger.shared.log("First source URL: \(urlString)", type: "Stream")
                                streamURL = URL(string: urlString)
                            }
                        } else {
                            Logger.shared.log("No streams or sources found in result", type: "Error")
                        }
                        
                        if let url = streamURL {
                            Logger.shared.log("Attempting to play URL: \(url.absoluteString)", type: "Stream")
                            
                            let headers = [
                                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:135.0) Gecko/20100101 Firefox/135.0"
                            ]
                            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                            
                            let playerItem = AVPlayerItem(asset: asset)
                            
                            let newPlayer = AVPlayer(playerItem: playerItem)
                            self.player = newPlayer
                            
                            let playerVC = NormalPlayer()
                            playerVC.player = newPlayer
                            self.playerViewController = playerVC
                            
                            DispatchQueue.main.async {
                                guard let windowScene = UIApplication.shared.connectedScenes
                                    .compactMap({ $0 as? UIWindowScene })
                                    .first(where: { $0.activationState == .foregroundActive }),
                                      let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                                      let rootVC = window.rootViewController else {
                                    Logger.shared.log("Could not find root view controller", type: "Error")
                                    return
                                }
                                
                                var topVC = rootVC
                                while let presented = topVC.presentedViewController {
                                    topVC = presented
                                }
                                
                                Logger.shared.log("Presenting player from: \(type(of: topVC))", type: "Stream")
                                
                                topVC.present(playerVC, animated: true) {
                                    Logger.shared.log("Player presented successfully", type: "Stream")
                                    newPlayer.play()
                                }
                            }
                        } else {
                            Logger.shared.log("Failed to create URL from stream string", type: "Error")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Compact Media Result Row
struct CompactMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let episode: TMDBEpisode?
    let onTap: () -> Void
    
    private var similarityScore: Double {
        calculateSimilarity(original: originalTitle, result: result.title)
    }
    
    private var scoreColor: Color {
        if similarityScore > 0.8 { return .green }
        else if similarityScore > 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                KFImage(URL(string: result.imageUrl))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 55)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text("\(Int(similarityScore * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(scoreColor)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return LevenshteinDistance.calculateSimilarity(original: original, result: result)
    }
}

struct EnhancedMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let episode: TMDBEpisode?
    let onTap: () -> Void
    
    private var similarityScore: Double {
        calculateSimilarity(original: originalTitle, result: result.title)
    }
    
    private var scoreColor: Color {
        if similarityScore > 0.8 { return .green }
        else if similarityScore > 0.6 { return .orange }
        else { return .red }
    }
    
    private var matchQuality: String {
        if similarityScore > 0.8 { return "Excellent" }
        else if similarityScore > 0.6 { return "Good" }
        else { return "Fair" }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                KFImage(URL(string: result.imageUrl))
                    .placeholder {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 95)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    if let episode = episode {
                        HStack {
                            Image(systemName: "tv")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Episode \(episode.episodeNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !episode.name.isEmpty {
                                Text("• \(episode.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(scoreColor)
                                .frame(width: 6, height: 6)
                            
                            Text(matchQuality)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(scoreColor)
                        }
                        
                        Text("• \(Int(similarityScore * 100))% match")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return LevenshteinDistance.calculateSimilarity(original: original, result: result)
    }
}

struct MediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let episode: TMDBEpisode?
    let onTap: () -> Void
    
    private var similarityScore: Double {
        LevenshteinDistance.calculateSimilarity(original: originalTitle, result: result.title)
    }
    
    private var scoreColor: Color {
        if similarityScore > 0.8 { return .green }
        else if similarityScore > 0.6 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                KFImage(URL(string: result.imageUrl))
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let episode = episode {
                        Text("Episode \(episode.episodeNumber): \(episode.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("Match:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(similarityScore * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(scoreColor)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
