//
//  TMDBService.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import Foundation

class TMDBService: ObservableObject {
    static let shared = TMDBService()
    
    static let tmdbBaseURL = "https://api.themoviedb.org/3"
    static let tmdbImageBaseURL = "https://image.tmdb.org/t/p/w500"
    
    private let apiKey = "738b4edd0a156cc126dc4a4b8aea4aca"
    private let baseURL = tmdbBaseURL
    
    private init() {}
    
    private var currentLanguage: String {
        return UserDefaults.standard.string(forKey: "tmdbLanguage") ?? "en-US"
    }
    
    // MARK: - Multi Search (Movies and TV Shows)
    func searchMulti(query: String) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/multi?api_key=\(apiKey)&query=\(encodedQuery)&language=\(currentLanguage)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Search Movies
    func searchMovies(query: String) async throws -> [TMDBMovie] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedQuery)&language=\(currentLanguage)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBMovieSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Search TV Shows
    func searchTVShows(query: String) async throws -> [TMDBTVShow] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/tv?api_key=\(apiKey)&query=\(encodedQuery)&language=\(currentLanguage)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBTVSearchResponse.self, from: data)
            return response.results
        } catch {
            throw TMDBError.networkError(error)
        }
    }
}

// MARK: - Error Handling
enum TMDBError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to decode response"
        case .missingAPIKey:
            return "API key is missing. Please add your TMDB API key."
        }
    }
}
