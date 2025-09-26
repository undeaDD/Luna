//
//  ModulesSearchResultsSheet.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import AVKit
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
    let tmdbId: Int
    
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
    @State private var showingStreamErrorAlert = false
    @State private var streamErrorMessage = ""
    @State private var showingAlgorithmPicker = false
    @State private var showingFilterEditor = false
    @State private var highQualityThreshold: Double = 0.9
    @State private var showingSeasonPicker = false
    @State private var showingEpisodePicker = false
    @State private var availableSeasons: [[EpisodeLink]] = []
    @State private var selectedSeasonIndex = 0
    @State private var pendingEpisodes: [EpisodeLink] = []
    @State private var pendingResult: SearchItem?
    @State private var pendingJSController: JSController?
    
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var algorithmManager = AlgorithmManager.shared
    
    private var servicesWithResults: [(service: Services, results: [SearchItem])] {
        moduleResults.filter { !$0.results.isEmpty }
    }
    
    private var shouldShowOriginalTitle: Bool {
        guard let originalTitle = originalTitle else { return false }
        return !originalTitle.isEmpty && originalTitle.lowercased() != mediaTitle.lowercased()
    }
    
    private var displayTitle: String {
        if let episode = selectedEpisode {
            return "\(mediaTitle) S\(episode.seasonNumber)E\(episode.episodeNumber)"
        } else {
            return mediaTitle
        }
    }
    
    private var episodeSeasonInfo: String {
        if let episode = selectedEpisode {
            return "S\(episode.seasonNumber)E\(episode.episodeNumber)"
        }
        return ""
    }
    
    private var mediaTypeText: String {
        return isMovie ? "Movie" : "TV Show"
    }
    
    private var mediaTypeColor: Color {
        return isMovie ? .purple : .green
    }
    
    private var searchStatusText: String {
        if isSearching {
            return "Searching... (\(searchedServices.count)/\(totalServicesCount))"
        } else {
            return "Search complete"
        }
    }
    
    private var searchStatusColor: Color {
        return isSearching ? .secondary : .green
    }
    
    private func lowerQualityResultsText(count: Int) -> String {
        let plural = count == 1 ? "" : "s"
        let threshold = Int(highQualityThreshold * 100)
        return "\(count) lower quality result\(plural) (<\(threshold)%)"
    }
    
    @ViewBuilder
    private var searchInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Searching for:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(displayTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let episode = selectedEpisode, !episode.name.isEmpty {
                    HStack {
                        Text(episode.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(episodeSeasonInfo)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .cornerRadius(8)
                    }
                }
                
                statusBar
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var statusBar: some View {
        HStack {
            Text(mediaTypeText)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(mediaTypeColor.opacity(0.2))
                .foregroundColor(mediaTypeColor)
                .cornerRadius(8)
            
            Spacer()
            
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(searchStatusText)
                        .font(.caption)
                        .foregroundColor(searchStatusColor)
                }
            } else {
                Text(searchStatusText)
                    .font(.caption)
                    .foregroundColor(searchStatusColor)
            }
        }
    }
    
    @ViewBuilder
    private var noActiveServicesSection: some View {
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
    }
    
    @ViewBuilder
    private var servicesResultsSection: some View {
        ForEach(Array(serviceManager.activeServices.enumerated()), id: \.element.id) { index, service in
            serviceSection(service: service)
        }
    }
    
    @ViewBuilder
    private func serviceSection(service: Services) -> some View {
        let moduleResult = moduleResults.first { $0.service.id == service.id }
        let hasSearched = searchedServices.contains(service.id)
        let isCurrentlySearching = isSearching && !hasSearched
        
        if let result = moduleResult {
            let filteredResults = filterResults(for: result.results)
            
            Section(header: serviceHeader(for: service, highQualityCount: filteredResults.highQuality.count, lowQualityCount: filteredResults.lowQuality.count, isSearching: false)) {
                if result.results.isEmpty {
                    noResultsRow
                } else {
                    serviceResultsContent(filteredResults: filteredResults, service: service)
                }
            }
        } else if isCurrentlySearching {
            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: true)) {
                searchingRow
            }
        } else if !isSearching && !hasSearched {
            Section(header: serviceHeader(for: service, highQualityCount: 0, lowQualityCount: 0, isSearching: false)) {
                notSearchedRow
            }
        }
    }
    
    @ViewBuilder
    private var noResultsRow: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("No results found")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var searchingRow: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Searching...")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var notSearchedRow: some View {
        HStack {
            Image(systemName: "minus.circle")
                .foregroundColor(.gray)
            Text("Not searched")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func serviceResultsContent(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Services) -> some View {
        ForEach(filteredResults.highQuality, id: \.id) { searchResult in
            EnhancedMediaResultRow(
                result: searchResult,
                originalTitle: mediaTitle,
                alternativeTitle: originalTitle,
                episode: selectedEpisode,
                onTap: {
                    selectedResult = searchResult
                    showingPlayAlert = true
                }, highQualityThreshold: highQualityThreshold
            )
        }
        
        if !filteredResults.lowQuality.isEmpty {
            lowQualityResultsSection(filteredResults: filteredResults, service: service)
        }
    }
    
    @ViewBuilder
    private func lowQualityResultsSection(filteredResults: (highQuality: [SearchItem], lowQuality: [SearchItem]), service: Services) -> some View {
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
                
                Text(lowerQualityResultsText(count: filteredResults.lowQuality.count))
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
                    }, highQualityThreshold: highQualityThreshold
                )
            }
        }
    }
    
    @ViewBuilder
    private var playAlertButtons: some View {
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
    }
    
    @ViewBuilder
    private var playAlertMessage: some View {
        if let result = selectedResult, let episode = selectedEpisode {
            Text("Play Episode \(episode.episodeNumber) of '\(result.title)'?")
        } else if let result = selectedResult {
            Text("Play '\(result.title)'?")
        }
    }
    
    @ViewBuilder
    private var streamFetchingOverlay: some View {
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
                            
                            Text("Trying to resolve playable servers for:\n\(currentFetchingTitle)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                            
                            if !streamFetchProgress.isEmpty {
                                Text(streamFetchProgress)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
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
    }
    
    @ViewBuilder
    private var qualityThresholdAlertContent: some View {
        TextField("Threshold (0.0 - 1.0)", value: $highQualityThreshold, format: .number)
            .keyboardType(.decimalPad)
        
        Button("Save") {
            highQualityThreshold = max(0.0, min(1.0, highQualityThreshold))
            UserDefaults.standard.set(highQualityThreshold, forKey: "highQualityThreshold")
        }
        
        Button("Cancel", role: .cancel) {
            highQualityThreshold = UserDefaults.standard.object(forKey: "highQualityThreshold") as? Double ?? 0.9
        }
    }
    
    @ViewBuilder
    private var qualityThresholdAlertMessage: some View {
        Text("Set the minimum similarity score (0.0 to 1.0) for results to be considered high quality. Current: \(String(format: "%.2f", highQualityThreshold)) (\(Int(highQualityThreshold * 100))%)")
    }
    
    @ViewBuilder
    private var serverSelectionDialogContent: some View {
        ForEach(Array(streamOptions.enumerated()), id: \.element.id) { index, option in
            Button(option.name) {
                if let service = pendingService {
                    playStreamURL(option.url, service: service, subtitles: pendingSubtitles, headers: option.headers)
                }
            }
        }
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    private var serverSelectionDialogMessage: some View {
        Text("Choose a server to stream from")
    }
    
    @ViewBuilder
    private var seasonPickerDialogContent: some View {
        ForEach(Array(availableSeasons.enumerated()), id: \.offset) { index, season in
            Button("Season \(index + 1) (\(season.count) episodes)") {
                selectedSeasonIndex = index
                pendingEpisodes = season
                showingSeasonPicker = false
                showingEpisodePicker = true
            }
        }
        Button("Cancel", role: .cancel) {
            resetPickerState()
        }
    }
    
    @ViewBuilder
    private var seasonPickerDialogMessage: some View {
        Text("Season \(selectedEpisode?.seasonNumber ?? 1) not found. Please choose the correct season:")
    }
    
    @ViewBuilder
    private var episodePickerDialogContent: some View {
        ForEach(pendingEpisodes, id: \.href) { episode in
            Button("Episode \(episode.number)") {
                proceedWithSelectedEpisode(episode)
            }
        }
        Button("Cancel", role: .cancel) {
            resetPickerState()
        }
    }
    
    @ViewBuilder
    private var episodePickerDialogMessage: some View {
        if let episode = selectedEpisode {
            Text("Choose the correct episode for S\(episode.seasonNumber)E\(episode.episodeNumber):")
        } else {
            Text("Choose an episode:")
        }
    }
    
    private func filterResults(for results: [SearchItem]) -> (highQuality: [SearchItem], lowQuality: [SearchItem]) {
        let sortedResults = results.map { result in
            let primarySimilarity = calculateSimilarity(original: mediaTitle, result: result.title)
            let originalSimilarity = originalTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
            let bestSimilarity = max(primarySimilarity, originalSimilarity)
            
            return (result: result, similarity: bestSimilarity)
        }.sorted { $0.similarity > $1.similarity }
        
        let highQuality = sortedResults.filter { $0.similarity >= highQualityThreshold }.map { $0.result }
        let lowQuality = sortedResults.filter { $0.similarity < highQualityThreshold }.map { $0.result }
        
        return (highQuality, lowQuality)
    }
    
    var body: some View {
        NavigationView {
            List {
                searchInfoSection
                
                if serviceManager.activeServices.isEmpty {
                    noActiveServicesSection
                } else {
                    servicesResultsSection
                }
            }
            .navigationTitle("Services Result")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section("Matching Algorithm") {
                            ForEach(SimilarityAlgorithm.allCases, id: \.self) { algorithm in
                                Button(action: {
                                    algorithmManager.selectedAlgorithm = algorithm
                                }) {
                                    HStack {
                                        Text(algorithm.displayName)
                                        if algorithmManager.selectedAlgorithm == algorithm {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section("Filter Settings") {
                            Button(action: {
                                showingFilterEditor = true
                            }) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Quality Threshold")
                                    Spacer()
                                    Text("\(Int(highQualityThreshold * 100))%")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert("Play Content", isPresented: $showingPlayAlert) {
            playAlertButtons
        } message: {
            playAlertMessage
        }
        .overlay(streamFetchingOverlay)
        .onAppear {
            startProgressiveSearch()
            highQualityThreshold = UserDefaults.standard.object(forKey: "highQualityThreshold") as? Double ?? 0.9
        }
        .alert("Quality Threshold", isPresented: $showingFilterEditor) {
            qualityThresholdAlertContent
        } message: {
            qualityThresholdAlertMessage
        }
        .confirmationDialog("Select Server", isPresented: $showingStreamMenu, titleVisibility: .visible) {
            serverSelectionDialogContent
        } message: {
            serverSelectionDialogMessage
        }
        .confirmationDialog("Select Season", isPresented: $showingSeasonPicker, titleVisibility: .visible) {
            seasonPickerDialogContent
        } message: {
            seasonPickerDialogMessage
        }
        .confirmationDialog("Select Episode", isPresented: $showingEpisodePicker, titleVisibility: .visible) {
            episodePickerDialogContent
        } message: {
            episodePickerDialogMessage
        }
        .alert("Stream Error", isPresented: $showingStreamErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(streamErrorMessage)
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
        return algorithmManager.calculateSimilarity(original: original, result: result)
    }
    
    private func resetPickerState() {
        availableSeasons = []
        pendingEpisodes = []
        pendingResult = nil
        pendingJSController = nil
        selectedSeasonIndex = 0
        isFetchingStreams = false
    }
    
    private func processStream(service: Services, href: String, result: SearchItem? = nil) {
        pendingResult = result
        pendingService = service
        isFetchingStreams = true
        currentFetchingTitle = result?.title ?? href
        streamFetchProgress = ""
        
        let jsPath = serviceManager.servicesDirectory.appendingPathComponent(service.localPath).appendingPathComponent("script.js")
        
        Task {
            do {
                let jsContent = try String(contentsOf: jsPath, encoding: .utf8)
                let jsController = JSController()
                pendingJSController = jsController
                jsController.loadScript(jsContent)
                
                let completion: ((streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?)) -> Void = { resultTuple in
                    DispatchQueue.main.async {
                        self.isFetchingStreams = false
                        let subtitles = resultTuple.subtitles
                        var options: [StreamOption] = []
                        
                        if let sources = resultTuple.sources, !sources.isEmpty {
                            for (index, src) in sources.enumerated() {
                                let title = (src["title"] as? String) ?? "Stream \(index + 1)"
                                let url = (src["streamUrl"] as? String) ?? (src["stream"] as? String) ?? ""
                                let headers = src["headers"] as? [String: String]
                                if !url.isEmpty {
                                    options.append(StreamOption(name: title, url: url, headers: headers))
                                }
                            }
                        } else if let streams = resultTuple.streams, !streams.isEmpty {
                            for (index, s) in streams.enumerated() {
                                options.append(StreamOption(name: "Stream \(index + 1)", url: s, headers: nil))
                            }
                        }
                        
                        if options.count == 0 {
                            if let streams = resultTuple.streams, streams.count == 1, let single = streams.first {
                                self.playStreamURL(single, service: service, subtitles: subtitles, headers: nil)
                                return
                            }
                            
                            Logger.shared.log("No streams found for \(href)", type: "Stream")
                            self.streamFetchProgress = "No streams found"
                            self.streamErrorMessage = "No playable streams were found for \(self.currentFetchingTitle). The service may not provide a direct stream or the module failed to resolve a playable URL."
                            self.showingStreamErrorAlert = true
                            return
                        }
                        
                        if options.count == 1 {
                            let opt = options[0]
                            self.playStreamURL(opt.url, service: service, subtitles: subtitles, headers: opt.headers)
                        } else {
                            self.streamOptions = options
                            self.pendingSubtitles = subtitles
                            self.showingStreamMenu = true
                        }
                    }
                }
                
                jsController.fetchStreamUrlJS(episodeUrl: href, softsub: service.metadata.softsub == true, module: service, completion: completion)
                
            } catch {
                DispatchQueue.main.async {
                    self.isFetchingStreams = false
                    self.streamFetchProgress = "Failed to load module script"
                    self.streamErrorMessage = "Failed to load the service module script for \(service.metadata.sourceName). The module file may be missing or corrupted."
                    self.showingStreamErrorAlert = true
                    Logger.shared.log("Failed to load script for service \(service.metadata.sourceName): \(error)", type: "Error")
                }
            }
        }
    }
    
    private func playContent(_ result: SearchItem) {
        if let module = moduleResults.first(where: { $0.results.contains(where: { $0.href == result.href }) }) {
            processStream(service: module.service, href: result.href, result: result)
        } else {
            if let first = serviceManager.activeServices.first {
                processStream(service: first, href: result.href, result: result)
            } else {
                Logger.shared.log("No active service available to play content", type: "Error")
            }
        }
    }
    
    private func playStreamURL(_ url: String, service: Services, subtitles: [String]?, headers: [String: String]?) {
        isFetchingStreams = false
        showingStreamMenu = false
        pendingSubtitles = nil
        pendingService = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let streamURL = URL(string: url) else {
                Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
                return
            }
            
            let externalRaw = UserDefaults.standard.string(forKey: "externalPlayer") ?? ExternalPlayer.none.rawValue
            let external = ExternalPlayer(rawValue: externalRaw) ?? .none
            let schemeUrl = external.schemeURL(for: url)
            
            if let scheme = schemeUrl, UIApplication.shared.canOpenURL(scheme) {
                UIApplication.shared.open(scheme, options: [:], completionHandler: nil)
                Logger.shared.log("Opening external player with scheme: \(scheme)", type: "General")
                return
            }
            
            let playerVC = NormalPlayer()
            
            let serviceURL = service.metadata.baseUrl
            var finalHeaders: [String: String] = [
                "Origin": serviceURL,
                "Referer": serviceURL,
                "User-Agent": URLSession.randomUserAgent
            ]
            
            if let custom = headers {
                Logger.shared.log("Using custom headers: \(custom)", type: "Stream")
                for (k, v) in custom {
                    finalHeaders[k] = v
                }
                
                if finalHeaders["User-Agent"] == nil {
                    finalHeaders["User-Agent"] = URLSession.randomUserAgent
                }
            }
            
            Logger.shared.log("Final headers: \(finalHeaders)", type: "Stream")
            
            let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
            let item = AVPlayerItem(asset: asset)
            playerVC.player = AVPlayer(playerItem: item)
            if isMovie {
                playerVC.mediaInfo = .movie(id: tmdbId, title: mediaTitle)
            } else if let episode = selectedEpisode {
                playerVC.mediaInfo = .episode(showId: tmdbId, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
            }
            playerVC.modalPresentationStyle = .fullScreen
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.topmostViewController().present(playerVC, animated: true) {
                    playerVC.player?.play()
                }
            } else {
                Logger.shared.log("Failed to find root view controller to present player", type: "Error")
                playerVC.player?.play()
            }
        }
    }
    
    private func proceedWithSelectedEpisode(_ episode: EpisodeLink) {
        showingEpisodePicker = false
        isFetchingStreams = true
        currentFetchingTitle = "Episode \(episode.number)"
        
        if let service = pendingService {
            processStream(service: service, href: episode.href, result: pendingResult)
        } else if let module = moduleResults.first {
            processStream(service: module.service, href: episode.href, result: pendingResult)
        } else if let first = serviceManager.activeServices.first {
            processStream(service: first, href: episode.href, result: pendingResult)
        } else {
            Logger.shared.log("No service available to fetch episode", type: "Error")
            isFetchingStreams = false
        }
    }
}

struct CompactMediaResultRow: View {
    let result: SearchItem
    let originalTitle: String
    let alternativeTitle: String?
    let episode: TMDBEpisode?
    let onTap: () -> Void
    let highQualityThreshold: Double
    
    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
    }
    
    private var scoreColor: Color {
        if similarityScore >= highQualityThreshold { return .green }
        else if similarityScore >= 0.75 { return .orange }
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
    let highQualityThreshold: Double
    
    private var similarityScore: Double {
        let primarySimilarity = calculateSimilarity(original: originalTitle, result: result.title)
        let alternativeSimilarity = alternativeTitle.map { calculateSimilarity(original: $0, result: result.title) } ?? 0.0
        return max(primarySimilarity, alternativeSimilarity)
    }
    
    private var scoreColor: Color {
        if similarityScore >= highQualityThreshold { return .green }
        else if similarityScore >= 0.75 { return .orange }
        else { return .red }
    }
    
    private var matchQuality: String {
        if similarityScore >= highQualityThreshold { return "Excellent" }
        else if similarityScore >= 0.75 { return "Good" }
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
