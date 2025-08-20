//
//  JaroWinklerSimilarity.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//

import Foundation

class JaroWinklerSimilarity {
    public static func calculateSimilarity(original: String, result: String) -> Double {
        let normalizedOriginal = original.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        let normalizedResult = result.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        
        return jaroWinklerSimilarity(normalizedOriginal, normalizedResult)
    }
    
    public static func jaroWinklerSimilarity(_ s1: String, _ s2: String) -> Double {
        let jaroSimilarity = jaroSimilarity(s1, s2)
        
        if jaroSimilarity < 0.7 {
            return jaroSimilarity
        }
        
        let prefixLength = min(4, commonPrefixLength(s1, s2))
        return jaroSimilarity + (0.1 * Double(prefixLength) * (1.0 - jaroSimilarity))
    }
    
    private static func jaroSimilarity(_ s1: String, _ s2: String) -> Double {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        if s1Count == 0 && s2Count == 0 { return 1.0 }
        if s1Count == 0 || s2Count == 0 { return 0.0 }
        
        let matchWindow = max(s1Count, s2Count) / 2 - 1
        let s1Matches = Array(repeating: false, count: s1Count)
        let s2Matches = Array(repeating: false, count: s2Count)
        
        var matches = 0
        var transpositions = 0
        
        var s1MatchesMutable = s1Matches
        var s2MatchesMutable = s2Matches
        
        for i in 0..<s1Count {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, s2Count)
            
            for j in start..<end {
                if s2MatchesMutable[j] || s1Array[i] != s2Array[j] {
                    continue
                }
                
                s1MatchesMutable[i] = true
                s2MatchesMutable[j] = true
                matches += 1
                break
            }
        }
        
        if matches == 0 { return 0.0 }
        
        var k = 0
        for i in 0..<s1Count {
            if !s1MatchesMutable[i] { continue }
            
            while !s2MatchesMutable[k] {
                k += 1
            }
            
            if s1Array[i] != s2Array[k] {
                transpositions += 1
            }
            k += 1
        }
        
        let jaro = (Double(matches) / Double(s1Count) +
                    Double(matches) / Double(s2Count) +
                    (Double(matches) - Double(transpositions) / 2.0) / Double(matches)) / 3.0
        
        return jaro
    }
    
    private static func commonPrefixLength(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let minLength = min(s1Array.count, s2Array.count)
        
        for i in 0..<minLength {
            if s1Array[i] != s2Array[i] {
                return i
            }
        }
        
        return minLength
    }
}
