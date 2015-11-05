//
//  TCCAnimationTileOverlay.swift
//  Pods
//
//  Created by Kiavash Faisali on 11/5/15.
//
//

import UIKit
import MapKit

@objc protocol TCCAnimationTileOverlayDelegate {
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didChangeFromAnimationState previousAnimationState: TCCAnimationState, toAnimationState currentAnimationState: TCCAnimationState)
    
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didAnimationWithAnimationFrameIndex animationFrameIndex: Int)
}

@objc enum TCCAnimationState: Int {
    case TCCAnimationStateStopped = 0
    case TCCAnimationStateLoading
    case TCCAnimationStateAnimating
    case TCCAnimationStateScrubbing
}

@objc enum TCCAnimationTileOverlayError: Int {
    case TCCAnimationTileOverlayErrorInvalidZoomLevel = 1001
    case TCCAnimationTileOverlayErrorBadURLResponseCode
    case TCCAnimationTileOverlayErrorNoImageData
    case TCCAnimationTileOverlayErrorNoFrames
}

class TCCAnimationTileOverlay: MKTileOverlay {
    weak var delegate: TCCAnimationTileOverlayDelegate?
    
    var currentFrameIndex: Int
    private(set) var numberOfAnimationFrames: Int
    private(set) var currentAnimationState: TCCAnimationState
    
    var templateURLs: NSArray
    
    init(templateURLs: NSArray, frameDuration: NSTimeInterval, minimumZ: NSInteger, maximumZ: NSInteger, tileSize: CGSize) {
        
    }
    
    func startAnimating() {
        
    }
    
    func pauseAnimating() {
        
    }
    
    func cancelLoading() {
        
    }
    
    func moveToFrameIndex(frameIndex: NSInteger, isContinuouslyMoving: Bool) {
        
    }
    
    func canAnimateForMapRect(rect: MKMapRect, zoomLevel: NSInteger) {
        
    }
    
    func fetchTilesForMapRect(mapRect: MKMapRect, zoomLevel: UInt, progressHandler: ((loadedFrameIndex: UInt) -> Void), completionHandler: ((success: Bool, error: NSError) -> Void)) {
        
    }
    
    func animationTileForMapRect(mapRect: MKMapRect, zoomLevel: UInt) -> TCCAnimationTile {
        
    }
    
    func staticTileForMapRect(mapRect: MKMapRect, zoomLevel: UInt) -> TCCAnimationTile {
        
    }
    
    func cachedTilesForMapRect(rect: MKMapRect, zoomLevel: UInt) -> NSArray {
        
    }
    
    func cachedStaticTilesForMapRect(rect: MKMapRect, zoomLevel: UInt) -> NSArray {
        
    }
}
