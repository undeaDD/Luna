//
//  TMDBModels.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import Foundation

// MARK: - Search Response
struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBSearchResult]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Search Result
struct TMDBSearchResult: Codable, Identifiable {
    let id: Int
    let mediaType: String
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double
    let popularity: Double
    
    enum CodingKeys: String, CodingKey {
        case id, overview, popularity
        case mediaType = "media_type"
        case title, name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }
    
    // Computed properties for easier access
    var displayTitle: String {
        return title ?? name ?? "Unknown Title"
    }
    
    var displayDate: String {
        return releaseDate ?? firstAirDate ?? ""
    }
    
    var isMovie: Bool {
        return mediaType == "movie"
    }
    
    var isTVShow: Bool {
        return mediaType == "tv"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
}

// MARK: - Movie Search Response
struct TMDBMovieSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - TV Show Search Response
struct TMDBTVSearchResponse: Codable {
    let page: Int
    let results: [TMDBTVShow]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Movie Model
struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let popularity: Double
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
}

// MARK: - TV Show Model
struct TMDBTVShow: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double
    let popularity: Double
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "\(TMDBService.tmdbImageBaseURL)\(posterPath)"
    }
}
