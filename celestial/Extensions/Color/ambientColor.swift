//
//  ambientColor.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

extension Color {
    static func ambientColor(from image: UIImage?) -> Color {
        guard let image = image else { return Color.black }
        
        let resizedImage = image.resized(to: CGSize(width: 50, height: 50))
        guard let cgImage = resizedImage.cgImage else { return Color.black }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: 50,
            height: 50,
            bitsPerComponent: 8,
            bytesPerRow: 50 * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return Color.black }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 50, height: 50))
        
        guard let data = context.data else { return Color.black }
        let buffer = data.bindMemory(to: UInt8.self, capacity: 50 * 50 * 4)
        
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var totalBrightness: CGFloat = 0
        
        for i in stride(from: 0, to: 50 * 50 * 4, by: 4) {
            let red = CGFloat(buffer[i]) / 255.0
            let green = CGFloat(buffer[i + 1]) / 255.0
            let blue = CGFloat(buffer[i + 2]) / 255.0
            
            let brightness = (red * 0.299 + green * 0.587 + blue * 0.114)
            
            totalRed += red
            totalGreen += green
            totalBlue += blue
            totalBrightness += brightness
        }
        
        let pixelCount = CGFloat(50 * 50)
        let avgRed = totalRed / pixelCount
        let avgGreen = totalGreen / pixelCount
        let avgBlue = totalBlue / pixelCount
        let avgBrightness = totalBrightness / pixelCount
        let darkenFactor: CGFloat = avgBrightness > 0.5 ? 0.3 : 0.6
        
        return Color(
            red: avgRed * darkenFactor,
            green: avgGreen * darkenFactor,
            blue: avgBlue * darkenFactor
        )
    }
}
