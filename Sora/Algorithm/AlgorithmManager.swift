//
//  AlgorithmManager.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import Foundation

enum SimilarityAlgorithm: String, CaseIterable {
    case levenshtein = "levenshtein"
    case jaroWinkler = "jaro_winkler"
    
    var displayName: String {
        switch self {
        case .levenshtein:
            return "Levenshtein Distance"
        case .jaroWinkler:
            return "Jaro-Winkler Similarity"
        }
    }
    
    var description: String {
        switch self {
        case .levenshtein:
            return "When you need precise differences across all text available."
        case .jaroWinkler:
            return "When matching names, titles, or short strings where prefix similarity are important."
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
