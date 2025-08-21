//
//  AlgorithmManager.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import Foundation

enum SimilarityAlgorithm: String, CaseIterable {
    case jaroWinkler = "jaro_winkler"
    case levenshtein = "levenshtein"
    
    var displayName: String {
        switch self {
        case .jaroWinkler:
            return "Jaro-Winkler Similarity"
        case .levenshtein:
            return "Levenshtein Distance"
        }
    }
    
    var description: String {
        switch self {
        case .jaroWinkler:
            return "When matching names, titles, or short strings where prefix similarity are important."
        case .levenshtein:
            return "When you need precise differences across all text available."
        }
    }
}

class AlgorithmManager: ObservableObject {
    static let shared = AlgorithmManager()
    
    @Published var selectedAlgorithm: SimilarityAlgorithm {
        didSet {
            UserDefaults.standard.set(selectedAlgorithm.rawValue, forKey: "selectedSimilarityAlgorithm")
        }
    }
    
    private init() {
        let savedAlgorithm = UserDefaults.standard.string(forKey: "selectedSimilarityAlgorithm") ?? SimilarityAlgorithm.jaroWinkler.rawValue
        self.selectedAlgorithm = SimilarityAlgorithm(rawValue: savedAlgorithm) ?? .jaroWinkler
    }
    
    func calculateSimilarity(original: String, result: String) -> Double {
        switch selectedAlgorithm {
        case .levenshtein:
            return LevenshteinDistance.calculateSimilarity(original: original, result: result)
        case .jaroWinkler:
            return JaroWinklerSimilarity.calculateSimilarity(original: original, result: result)
        }
    }
}
