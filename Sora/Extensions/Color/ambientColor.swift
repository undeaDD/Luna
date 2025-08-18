//
//  ambientColor.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

extension Color {
    static func ambientColor(from image: UIImage?) -> Color {
        guard let image = image else { return Color.black }
        
        let resizedImage = image.resized(to: CGSize(width: 32, height: 32))
        guard let cgImage = resizedImage.cgImage else { return Color.black }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let width = 32
        let height = 32
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return Color.black }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return Color.black }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var weightedRed: CGFloat = 0
        var weightedGreen: CGFloat = 0
        var weightedBlue: CGFloat = 0
        var totalWeight: CGFloat = 0
        var colorCounts: [String: Int] = [:]
        
        let centerX = width / 2
        let centerY = height / 2
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                guard index + 3 < width * height * 4 else { continue }
                
                let red = CGFloat(buffer[index]) / 255.0
                let green = CGFloat(buffer[index + 1]) / 255.0
                let blue = CGFloat(buffer[index + 2]) / 255.0
                let alpha = CGFloat(buffer[index + 3]) / 255.0
                
                guard alpha > 0.1 && (red + green + blue) > 0.15 else { continue }
                
                let distanceFromCenter = sqrt(pow(CGFloat(x - centerX), 2) + pow(CGFloat(y - centerY), 2))
                let maxDistance = sqrt(pow(CGFloat(centerX), 2) + pow(CGFloat(centerY), 2))
                
                let centerWeight = 1.0 - (distanceFromCenter / maxDistance) * 0.3
                
                let brightness = red * 0.2126 + green * 0.7152 + blue * 0.0722
                let brightnessWeight = 1.0 - abs(brightness - 0.5) * 0.4
                
                let maxComponent = max(red, green, blue)
                let minComponent = min(red, green, blue)
                let saturation = maxComponent > 0 ? (maxComponent - minComponent) / maxComponent : 0
                let saturationWeight = 0.5 + saturation * 0.5
                
                let finalWeight = centerWeight * brightnessWeight * saturationWeight * alpha
                
                weightedRed += red * finalWeight
                weightedGreen += green * finalWeight
                weightedBlue += blue * finalWeight
                totalWeight += finalWeight
                
                let colorKey = "\(Int(red * 10))-\(Int(green * 10))-\(Int(blue * 10))"
                colorCounts[colorKey, default: 0] += 1
            }
        }
        
        guard totalWeight > 0 else { return Color.black }
        
        let avgRed = weightedRed / totalWeight
        let avgGreen = weightedGreen / totalWeight
        let avgBlue = weightedBlue / totalWeight
        
        let avgBrightness = avgRed * 0.2126 + avgGreen * 0.7152 + avgBlue * 0.0722
        
        let darkenFactor: CGFloat
        if avgBrightness > 0.8 {
            darkenFactor = 0.2
        } else if avgBrightness > 0.6 {
            darkenFactor = 0.3
        } else if avgBrightness > 0.4 {
            darkenFactor = 0.5
        } else if avgBrightness > 0.2 {
            darkenFactor = 0.7
        } else {
            darkenFactor = 0.9
        }
        
        let finalRed = max(0.05, min(0.95, avgRed * darkenFactor))
        let finalGreen = max(0.05, min(0.95, avgGreen * darkenFactor))
        let finalBlue = max(0.05, min(0.95, avgBlue * darkenFactor))
        
        return Color(
            red: finalRed,
            green: finalGreen,
            blue: finalBlue
        )
    }
}
