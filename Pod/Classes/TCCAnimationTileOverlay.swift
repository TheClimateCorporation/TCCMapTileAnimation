//
//  TCCAnimationTileOverlay.swift
//  Pods
//
//  Created by Kiavash Faisali on 11/5/15.
//
//

import UIKit

@objc protocol TCCAnimationTileOverlayDelegate {
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didChangeFromAnimationState previousAnimationState: TCCAnimationState, toAnimationState currentAnimationState: TCCAnimationState)
    
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didAnimationWithAnimationFrameIndex animationFrameIndex: NSInteger)
}

enum TCCAnimationState: NSUInteger {
    case TCCAnimationStateStopped = 0
    case TCCAnimationStateLoading
    case TCCAnimationStateAnimating
    case TCCAnimationStateScrubbing
}

enum TCCAnimationTileOverlayError: NSUInteger {
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
    
    func fetchTilesForMapRect(mapRect: MKMapRect, zoomLevel: NSUInteger, progressHandler: ((loadedFrameIndex: NSUInteger) -> Void), completionHandler: ((success: Bool, error: NSError) -> Void)) {
        
    }
    
    func animationTileForMapRect(mapRect: MKMapRect, zoomLevel: NSUInteger) -> TCCAnimationTile {
        
    }
    
    func staticTileForMapRect(mapRect: MKMapRect, zoomLevel: NSUInteger) -> TCCAnimationTile {
        
    }
    
    func cachedTilesForMapRect(rect: MKMapRect, zoomLevel: NSUInteger) -> NSArray {
        
    }
    
    func cachedStaticTilesForMapRect(rect: MKMapRect, zoomLevel: NSUInteger) -> NSArray {
        
    }
}
