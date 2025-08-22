//
//  ModulesSearchResultsSheet.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import AVKit
import UIKit
import SwiftUI
import Kingfisher

struct StreamOption {
    let id = UUID()
    let name: String
    let url: String
    let headers: [String: String]?
}

struct ModulesSearchResultsSheet: View {
    let mediaTitle: String
    let originalTitle: String?
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
    @State private var streamOptions: [StreamOption] = []
    @State private var pendingSubtitles: [String]?
    @State private var pendingService: Services?
    @State private var showingStreamMenu = false
    @State private var isFetchingStreams = false
    @State private var currentFetchingTitle = ""
    @State private var streamFetchProgress = ""
    
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var algorithmManager = AlgorithmManager.shared
    
    private var servicesWithResults: [(service: Services, results: [SearchItem])] {
        moduleResults.filter { !$0.results.isEmpty }
    }
    
    private func filterResults(for results: [SearchItem]) -> (highQuality: [SearchItem], lowQuality: [SearchItem]) {
        let sortedResults = results.map { result in
            let primarySimilarity = calculateSimilarity(original: mediaTitle, result: result.title)
            let originalSimilarity = originalTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
            let bestSimilarity = max(primarySimilarity, originalSimilarity)
            
            return (result: result, similarity: bestSimilarity)
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
                            
                            if let originalTitle = originalTitle, !originalTitle.isEmpty, originalTitle.lowercased() != mediaTitle.lowercased() {
                                Text("Also searching: \(originalTitle)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        } else {
                            Text(mediaTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if let originalTitle = originalTitle, !originalTitle.isEmpty, originalTitle.lowercased() != mediaTitle.lowercased() {
                                Text("Also searching: \(originalTitle)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
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
                    ForEach(Array(serviceManager.activeServices.enumerated()), id: \.element.id) { index, service in
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
                                            alternativeTitle: originalTitle,
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
                                                    alternativeTitle: originalTitle,
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
        .overlay(
            Group {
                if isFetchingStreams {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            VStack(spacing: 8) {
                                Text("Fetching Streams")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text(currentFetchingTitle)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                
                                if !streamFetchProgress.isEmpty {
                                    Text(streamFetchProgress)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal, 40)
                    }
                }
            }
        )
        .onAppear {
            startProgressiveSearch()
        }
        .confirmationDialog("Select Server", isPresented: $showingStreamMenu, titleVisibility: .visible) {
            ForEach(Array(streamOptions.enumerated()), id: \.element.id) { index, option in
                Button(option.name) {
                    if let service = pendingService {
                        playStreamURL(option.url, service: service, subtitles: pendingSubtitles, headers: option.headers)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose a server to stream from")
        }
    }
    
    private func startProgressiveSearch() {
        let activeServices = serviceManager.activeServices
        totalServicesCount = activeServices.count
        
        guard !activeServices.isEmpty else {
            isSearching = false
            return
        }
        let searchQuery = mediaTitle
        
        Task {
            await serviceManager.searchInActiveServicesProgressively(
                query: searchQuery,
                onResult: { service, results in
                    Task { @MainActor in
                        var newModuleResults = moduleResults
                        
                        if let existingIndex = newModuleResults.firstIndex(where: { $0.service.id == service.id }) {
                            newModuleResults[existingIndex] = (service: service, results: results)
                        } else {
                            newModuleResults.append((service: service, results: results))
                        }
                        
                        moduleResults = newModuleResults
                        searchedServices.insert(service.id)
                    }
                },
                onComplete: {
                    if let originalTitle = self.originalTitle,
                       !originalTitle.isEmpty,
                       originalTitle.lowercased() != self.mediaTitle.lowercased() {
                        
                        Task {
                            await self.serviceManager.searchInActiveServicesProgressively(
                                query: originalTitle,
                                onResult: { service, additionalResults in
                                    Task { @MainActor in
                                        if let existingIndex = self.moduleResults.firstIndex(where: { $0.service.id == service.id }) {
                                            let existingResults = self.moduleResults[existingIndex].results
                                            let existingHrefs = Set(existingResults.map { $0.href })
                                            let newResults = additionalResults.filter { !existingHrefs.contains($0.href) }
                                            let mergedResults = existingResults + newResults
                                            self.moduleResults[existingIndex] = (service: service, results: mergedResults)
                                        } else {
                                            self.moduleResults.append((service: service, results: additionalResults))
                                        }
                                    }
                                },
                                onComplete: {
                                    Task { @MainActor in
                                        self.isSearching = false
                                    }
                                }
                            )
                        }
                    } else {
                        Task { @MainActor in
                            self.isSearching = false
                        }
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
        guard !original.isEmpty && !result.isEmpty else {
            return 0.0
        }
        
        let cleanOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanOriginal.isEmpty && !cleanResult.isEmpty else {
            return 0.0
        }
        
        return algorithmManager.calculateSimilarity(original: cleanOriginal, result: cleanResult)
    }
    
    private func playContent(_ result: SearchItem) {
        Logger.shared.log("Starting playback for: \(result.title)", type: "Stream")
        
        isFetchingStreams = true
        currentFetchingTitle = result.title
        streamFetchProgress = "Initializing..."
        
        guard let service = serviceManager.activeServices.first(where: { service in
            moduleResults.contains { $0.service.id == service.id && $0.results.contains { $0.id == result.id } }
        }) else {
            Logger.shared.log("Could not find service for result: \(result.title)", type: "Error")
            isFetchingStreams = false
            return
        }
        
        Logger.shared.log("Using service: \(service.metadata.sourceName)", type: "Stream")
        streamFetchProgress = "Loading service: \(service.metadata.sourceName)"
        
        let jsController = JSController()
        let servicePath = serviceManager.servicesDirectory.appendingPathComponent(service.localPath)
        let jsPath = servicePath.appendingPathComponent("script.js")
        
        Logger.shared.log("JavaScript path: \(jsPath.path)", type: "Stream")
        
        guard FileManager.default.fileExists(atPath: jsPath.path) else {
            Logger.shared.log("JavaScript file not found for service: \(service.metadata.sourceName)", type: "Error")
            isFetchingStreams = false
            return
        }
        
        do {
            let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
            jsController.loadScript(jsContent)
            Logger.shared.log("JavaScript loaded successfully", type: "Stream")
            streamFetchProgress = "JavaScript loaded successfully"
        } catch {
            Logger.shared.log("Failed to load JavaScript for service \(service.metadata.sourceName): \(error.localizedDescription)", type: "Error")
            isFetchingStreams = false
            return
        }
        
        streamFetchProgress = "Fetching episodes..."
        
        jsController.fetchEpisodesJS(url: result.href) { episodes in
            DispatchQueue.main.async {
                Logger.shared.log("Fetched \(episodes.count) episodes for: \(result.title)", type: "Stream")
                self.streamFetchProgress = "Found \(episodes.count) episode\(episodes.count == 1 ? "" : "s")"
                
                if episodes.isEmpty {
                    Logger.shared.log("No episodes found for: \(result.title)", type: "Error")
                    self.isFetchingStreams = false
                    return
                }
                
                let targetHref: String
                
                if self.isMovie {
                    targetHref = episodes.first?.href ?? result.href
                    Logger.shared.log("Movie - Using href: \(targetHref)", type: "Stream")
                    self.streamFetchProgress = "Preparing movie stream..."
                } else {
                    guard let selectedEpisode = self.selectedEpisode else {
                        Logger.shared.log("No episode selected for TV show", type: "Error")
                        self.isFetchingStreams = false
                        return
                    }
                    
                    self.streamFetchProgress = "Finding episode S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber)..."
                    
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
                        self.isFetchingStreams = false
                        return
                    }
                    
                    let season = seasons[targetSeasonIndex]
                    guard let targetEpisode = season.first(where: { $0.number == targetEpisodeNumber }) else {
                        Logger.shared.log("Episode \(targetEpisodeNumber) not found in season \(selectedEpisode.seasonNumber). Available episodes: \(season.map { $0.number })", type: "Error")
                        self.isFetchingStreams = false
                        return
                    }
                    
                    targetHref = targetEpisode.href
                    Logger.shared.log("TV Show - S\(selectedEpisode.seasonNumber)E\(selectedEpisode.episodeNumber) - Using href: \(targetHref)", type: "Stream")
                    self.streamFetchProgress = "Found episode, fetching stream..."
                }
                
                jsController.fetchStreamUrlJS(episodeUrl: targetHref, module: service) { streamResult in
                    DispatchQueue.main.async {
                        let (streams, subtitles, sources) = streamResult
                        
                        Logger.shared.log("Stream fetch result - Streams: \(streams?.count ?? 0), Sources: \(sources?.count ?? 0)", type: "Stream")
                        self.streamFetchProgress = "Processing stream data..."
                        
                        var availableStreams: [StreamOption] = []
                        
                        if let sources = sources, !sources.isEmpty {
                            Logger.shared.log("Processing \(sources.count) sources with potential headers", type: "Stream")
                            
                            var hasNewFormat = false
                            for source in sources {
                                if source["title"] is String && source["streamUrl"] is String {
                                    hasNewFormat = true
                                    break
                                }
                            }
                            
                            if hasNewFormat {
                                Logger.shared.log("Detected new stream format with titles and headers", type: "Stream")
                                for source in sources {
                                    if let title = source["title"] as? String,
                                       let streamUrl = source["streamUrl"] as? String {
                                        let headers = source["headers"] as? [String: String]
                                        availableStreams.append(StreamOption(name: title, url: streamUrl, headers: headers))
                                        Logger.shared.log("Added stream: \(title) with headers: \(headers?.keys.joined(separator: ", ") ?? "none")", type: "Stream")
                                    }
                                }
                            } else {
                                Logger.shared.log("Using legacy source format", type: "Stream")
                                for (index, source) in sources.enumerated() {
                                    if let urlString = source["url"] as? String {
                                        let headers = source["headers"] as? [String: String]
                                        availableStreams.append(StreamOption(name: "Stream \(index + 1)", url: urlString, headers: headers))
                                    }
                                }
                            }
                        }
                        else if let streams = streams, streams.count > 1 {
                            var streamNames: [String] = []
                            var streamURLs: [String] = []
                            
                            for (_, stream) in streams.enumerated() {
                                if stream.hasPrefix("http") {
                                    streamURLs.append(stream)
                                } else {
                                    streamNames.append(stream)
                                }
                            }
                            
                            if !streamNames.isEmpty && !streamURLs.isEmpty {
                                let maxPairs = min(streamNames.count, streamURLs.count)
                                for i in 0..<maxPairs {
                                    availableStreams.append(StreamOption(name: streamNames[i], url: streamURLs[i], headers: nil))
                                }
                                
                                if streamURLs.count > streamNames.count {
                                    for i in streamNames.count..<streamURLs.count {
                                        availableStreams.append(StreamOption(name: "Stream \(i + 1)", url: streamURLs[i], headers: nil))
                                    }
                                }
                            } else if streamURLs.count > 1 {
                                for (index, url) in streamURLs.enumerated() {
                                    availableStreams.append(StreamOption(name: "Stream \(index + 1)", url: url, headers: nil))
                                }
                            } else if streams.count > 1 {
                                let urls = streams.filter { $0.hasPrefix("http") }
                                if urls.count > 1 {
                                    for (index, url) in urls.enumerated() {
                                        availableStreams.append(StreamOption(name: "Stream \(index + 1)", url: url, headers: nil))
                                    }
                                }
                            }
                        }
                        
                        if availableStreams.count > 1 {
                            Logger.shared.log("Found \(availableStreams.count) stream options, showing selection", type: "Stream")
                            self.streamOptions = availableStreams
                            self.pendingSubtitles = subtitles
                            self.pendingService = service
                            self.isFetchingStreams = false
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.showingStreamMenu = true
                            }
                            return
                        }
                        
                        var streamURL: URL?
                        var streamHeaders: [String: String]? = nil
                        
                        if let sources = sources, !sources.isEmpty {
                            let firstSource = sources.first!
                            
                            if let streamUrl = firstSource["streamUrl"] as? String {
                                Logger.shared.log("Found single stream URL from new format: \(streamUrl)", type: "Stream")
                                streamURL = URL(string: streamUrl)
                                streamHeaders = firstSource["headers"] as? [String: String]
                            } else if let urlString = firstSource["url"] as? String {
                                Logger.shared.log("Found single stream URL from legacy format: \(urlString)", type: "Stream")
                                streamURL = URL(string: urlString)
                                streamHeaders = firstSource["headers"] as? [String: String]
                            }
                        } else if let streams = streams, !streams.isEmpty {
                            let urlCandidates = streams.filter { $0.hasPrefix("http") }
                            if let firstURL = urlCandidates.first {
                                Logger.shared.log("Found single stream URL: \(firstURL)", type: "Stream")
                                streamURL = URL(string: firstURL)
                            } else {
                                Logger.shared.log("First stream URL: \(streams.first!)", type: "Stream")
                                streamURL = URL(string: streams.first!)
                            }
                        } else {
                            Logger.shared.log("No streams or sources found in result", type: "Error")
                        }
                        
                        if let url = streamURL {
                            self.playStreamURL(url.absoluteString, service: service, subtitles: subtitles, headers: streamHeaders)
                        } else {
                            Logger.shared.log("Failed to create URL from stream string", type: "Error")
                            self.isFetchingStreams = false
                        }
                    }
                }
            }
        }
    }
    
    private func playStreamURL(_ urlString: String, service: Services, subtitles: [String]?, headers customHeaders: [String: String]? = nil) {
        guard let url = URL(string: urlString) else {
            Logger.shared.log("Failed to create URL from stream string: \(urlString)", type: "Error")
            isFetchingStreams = false
            return
        }
        
        Logger.shared.log("Attempting to play URL: \(url.absoluteString)", type: "Stream")
        let serviceURL = service.metadata.baseUrl
        
        var headers = [
            "Origin": serviceURL,
            "Referer": serviceURL,
            "User-Agent": URLSession.randomUserAgent
        ]
        
        if let customHeaders = customHeaders {
            Logger.shared.log("Using custom headers: \(customHeaders)", type: "Stream")
            for (key, value) in customHeaders {
                headers[key] = value
            }
            
            if headers["User-Agent"] == nil {
                headers["User-Agent"] = URLSession.randomUserAgent
            }
        }
        
        Logger.shared.log("Final headers: \(headers)", type: "Stream")
        
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
                self.isFetchingStreams = false
                return
            }
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            Logger.shared.log("Presenting player from: \(type(of: topVC))", type: "Stream")
            self.isFetchingStreams = false
            
            topVC.present(playerVC, animated: true) {
                Logger.shared.log("Player presented successfully", type: "Stream")
                newPlayer.play()
            }
        }
    }
}

// MARK: - Compact Media Result Row
struct CompactMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let alternativeTitle: String?
    let episode: TMDBEpisode?
    let onTap: () -> Void
    
    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
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
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return AlgorithmManager.shared.calculateSimilarity(original: original, result: result)
    }
}

struct EnhancedMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let alternativeTitle: String?
    let episode: TMDBEpisode?
    let onTap: () -> Void
    
    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
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
                            .tint(Color.accentColor)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return AlgorithmManager.shared.calculateSimilarity(original: original, result: result)
    }
}

struct MediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let episode: TMDBEpisode?
    let onTap: () -> Void
    
    private var similarityScore: Double {
        AlgorithmManager.shared.calculateSimilarity(original: originalTitle, result: result.title)
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
                        
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .tint(Color.accentColor)
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
