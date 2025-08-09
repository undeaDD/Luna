//
//  ModulesSearchResultsSheet.swift
//  celestial
//
//  Created by Francesco on 09/08/25.
//

import SwiftUI
import Kingfisher

struct ModulesSearchResultsSheet: View {
    let moduleResults: [(service: Services, results: [SearchItem])]
    let mediaTitle: String
    let isMovie: Bool
    let selectedEpisode: TMDBEpisode?
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedResult: SearchItem?
    @State private var showingPlayAlert = false
    @State private var expandedServices: Set<UUID> = []
    
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
                        
                        Text(mediaTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
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
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                ForEach(moduleResults, id: \.service.id) { moduleResult in
                    let filteredResults = filterResults(for: moduleResult.results)
                    
                    Section(header: serviceHeader(for: moduleResult.service, highQualityCount: filteredResults.highQuality.count, lowQualityCount: filteredResults.lowQuality.count)) {
                        if moduleResult.results.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("No results found")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            ForEach(filteredResults.highQuality, id: \.id) { result in
                                EnhancedMediaResultRow(
                                    result: result,
                                    originalTitle: mediaTitle,
                                    episode: selectedEpisode,
                                    onTap: {
                                        selectedResult = result
                                        showingPlayAlert = true
                                    }
                                )
                            }
                            
                            if !filteredResults.lowQuality.isEmpty {
                                let isExpanded = expandedServices.contains(moduleResult.service.id)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if isExpanded {
                                            expandedServices.remove(moduleResult.service.id)
                                        } else {
                                            expandedServices.insert(moduleResult.service.id)
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
                                    ForEach(filteredResults.lowQuality, id: \.id) { result in
                                        CompactMediaResultRow(
                                            result: result,
                                            originalTitle: mediaTitle,
                                            episode: selectedEpisode,
                                            onTap: {
                                                selectedResult = result
                                                showingPlayAlert = true
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
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
                if let result = selectedResult {
                    playContent(result)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let result = selectedResult, let episode = selectedEpisode {
                Text("Play Episode \(episode.episodeNumber) of '\(result.title)'?")
            } else if let result = selectedResult {
                Text("Play '\(result.title)'?")
            }
        }
        .onAppear {
            let totalResults = moduleResults.reduce(0) { $0 + $1.results.count }
            let highQualityResults = moduleResults.reduce(0) { acc, moduleResult in
                acc + filterResults(for: moduleResult.results).highQuality.count
            }
            let lowQualityResults = moduleResults.reduce(0) { acc, moduleResult in
                acc + filterResults(for: moduleResult.results).lowQuality.count
            }
        }
    }
    
    @ViewBuilder
    private func serviceHeader(for service: Services, highQualityCount: Int, lowQualityCount: Int) -> some View {
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
    
    private func getResultCount(for service: Services) -> Int {
        return moduleResults.first { $0.service.id == service.id }?.results.count ?? 0
    }
    
    private func calculateSimilarity(original: String, result: String) -> Double {
        return LevenshteinDistance.calculateSimilarity(original: original, result: result)
    }
    
    private func playContent(_ result: SearchItem) {
        // TODO: Implement actual content play functionality
        if let episode = selectedEpisode {
            print("Playing: Episode \(episode.episodeNumber) of \(result.title) from \(result.href)")
        } else {
            print("Playing: \(result.title) from \(result.href)")
        }
        presentationMode.wrappedValue.dismiss()
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
