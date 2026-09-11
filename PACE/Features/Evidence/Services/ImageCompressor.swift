//
//  ImageCompressor.swift
//  PACE
//
//  Image processing utility:
//  - Resizes selected images to sensible mobile dimensions (max 1200px)
//  - Normalizes orientation
//  - Compresses to efficient JPEG binary before storage/upload
//

import UIKit

struct CompressedImageResult {
    let data: Data
    let image: UIImage
    let originalByteCount: Int
    let compressedByteCount: Int
}

enum ImageCompressor {
    static let maxDimension: CGFloat = 1200.0
    static let compressionQuality: CGFloat = 0.75
    
    /// Resizes and compresses an image for mobile storage/upload.
    static func compress(image: UIImage, maxDimension: CGFloat = maxDimension, quality: CGFloat = compressionQuality) -> CompressedImageResult? {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else {
            return nil
        }
        
        // Calculate aspect-ratio preserving target size
        let targetSize: CGSize
        if max(originalSize.width, originalSize.height) > maxDimension {
            if originalSize.width > originalSize.height {
                let scale = maxDimension / originalSize.width
                targetSize = CGSize(width: maxDimension, height: round(originalSize.height * scale))
            } else {
                let scale = maxDimension / originalSize.height
                targetSize = CGSize(width: round(originalSize.width * scale), height: maxDimension)
            }
        } else {
            targetSize = originalSize
        }
        
        // Render resized image using UIGraphicsImageRenderer (automatically fixes orientation)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0 // Use 1.0 so points equal pixels
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        guard let compressedData = resizedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        
        let originalBytes = image.jpegData(compressionQuality: 1.0)?.count ?? compressedData.count
        
        return CompressedImageResult(
            data: compressedData,
            image: resizedImage,
            originalByteCount: originalBytes,
            compressedByteCount: compressedData.count
        )
    }
}
