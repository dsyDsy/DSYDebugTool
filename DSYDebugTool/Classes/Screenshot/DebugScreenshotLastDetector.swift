//
//  DebugScreenshotLastDetector.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/10.
//

import Security
import Foundation

import UIKit
import Photos

class DebugScreenshotLastDetector {
    
    static func screenshotTaken(completion: @escaping((UIImage?)->())) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fetchLatestScreenshot(completion:completion)
        }
    }
    
    static func fetchLatestScreenshot(completion: @escaping((UIImage?)->())) {
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        // 查找截屏图片
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )
        
        guard let screenshotAlbum = smartAlbums.firstObject else {
            completion(nil)
            return
        }
        
        let assets = PHAsset.fetchAssets(in: screenshotAlbum, options: fetchOptions)
        
        if let asset = assets.firstObject {
            fetchImage(from: asset,completion: completion)
        }else{
            completion(nil)
        }
    }
    
    static func fetchImage(from asset: PHAsset,completion: @escaping((UIImage?)->())) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            print("获取到截屏图片")
            completion(image)
        }
    }
    

    
 
}
