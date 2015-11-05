//
//  TCCAnimationTileOverlayRenderer.swift
//  Pods
//
//  Created by Kiavash Faisali on 11/5/15.
//
//

import UIKit
import MapKit

class TCCAnimationTileOverlayRenderer: MKOverlayRenderer {
    /**
        Zoom level of the currently rendered overlay tiles. Value ranges from 1-20. Useful to
        fetch the tiles with the correct zoom level for the animation overlay.
    */
    public(set) var renderedTileZoomLevel: Int
    var drawDebugInfo: Bool
    
    init(overlay: MKOverlay) {
        super.init(overlay)
        
        if !(overlay is TCCAnimationTileOverlay) {
            fatalError("Unsupported overlay type - Must be of type TCCAnimationTileOverlay")
        }
        
        let animationOverlay = overlay as! TCCAnimationTileOverlay
        
        animationOverlay.addObserver(self, forKeyPath:"currentAnimationState", options: 0, context: NULL)
    }
    
    deinit {
        self.overlay.removeObserver(self, forKeyPath: "currentAnimationState")
    }
    
    // MARK: - Public Methods
    
}
