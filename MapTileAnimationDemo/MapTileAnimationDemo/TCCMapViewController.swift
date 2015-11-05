//
//  TCCMapViewController.swift
//  MapTileAnimationDemo
//
//  Created by Kiavash Faisali on 11/5/15.
//  Copyright © 2015 The Climate Corporation. All rights reserved.
//

import UIKit
import MapKit

class TCCMapViewController: UIViewController, MKMapViewDelegate, TCCAnimationTileOverlayDelegate, TCCTimeFrameParserDelegateProtocol, UIAlertViewDelegate {
    // MARK: - Properties
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var frameIndexLabel: UILabel!
    @IBOutlet weak var downloadProgressView: UIProgressView!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var timeSlider: UISlider!
    
    var timeFrameParser: TCCTimeFrameParser
    var animatedTileOverlay: TCCAnimationTileOverlay
    var animatedTileRenderer: TCCAnimationTileOverlayRenderer
    var alertView: UIAlertView
    
    // MARK: - Memory Warning
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let startingLocation = CLLocationCoordinate2DMake(30.33, -81.52)
        let span = MKCoordinateSpanMake(7.0, 7.0)
        let region = self.mapView.regionThatFits(MKCoordinateRegionMake(startingLocation, span)
        self.mapView.setRegion(region, animated: false)
        
        self.timeFrameParser = TCCTimeFrameParser(URLString: FUTURE_RADAR_FRAMES_URI, delegate: self)
    }

    // MARK: - UI Actions
    @IBAction func onSliderValueChange(slider: UISlider) {
        // Only advance the animated overlay to the next frame if the slider no longer matches the
        // current frame index
        let sliderVal = floor(slider.value)
        if sliderVal == self.animatedTileOverlay.currentFrameIndex {
            return
        }
        
        self.animatedTileOverlay.moveToFrameIndex(sliderVal, isContinuouslyMoving: true)
    }
    
    @IBAction func finishedSliding(slider: UISlider) {
        let sliderVal = floor(slider.value)
        
        self.animatedTileOverlay.moveToFrame(sliderVal, isContinuouslyMoving: false)
    }
    
    @IBAction func onHandleStartStopAction(sender: UIButton) {
        if self.animatedTileOverlay.currentAnimationState == TCCAnimationState.TCCAnimationStateStopped {
            self.animatedTileOverlay.fetchTilesForMapRect(self.mapView.visibleMapRect, zoomLevel: self.animatedTileRenderer.renderedTileZoomLevel, progressHandler: { (loadedFrameIndex) in
                    self.downloadProgressView.setProgress((loadedFrameIndex + 1) / self.animatedTileOverlay.numberOfAnimationFrames, animated: true)
                }) {
                    (success, error) in
                    
                    if success {
                        self.timeSlider.enabled = true
                        self.animatedTileOverlay.startAnimating()
                        return
                    }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.displayError(error)
                    }
            }
        }
        else if self.animatedTileOverlay.currentAnimationState == TCCAnimationState.TCCAnimationStateLoading {
            self.animatedTileOverlay.cancelLoading()
        }
        else if self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating {
            self.animatedTileOverlay.pauseAnimating()
        }
    }
    
    func displayError(error: NSError) {
        let alertView = UIAlertView(title: "Error", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
        self.alertView = alertView
        alertView.show()
    }
    
    // MARK: - Protocol Implementations
    // MARK: - TCCTimeFrameParserDelegate Protocol
    func didLoadTimeStampData() {
        // Only use a subset of the available template URLs
        let templateURLs = self.timeFrameParser.templateFrameTimeURLs
        let pluckedArray = NSMutableArray()
        
        for (var i = 0; i < templateURLs.count; i += 3) {
            pluckedArray.addObject(templateURLs[i])
        }
        
        // Setting up the overlay's maximumZ caps the zoom level of the tiles that get fetched.
        // If the user zooms closer in than this level, then tiles from the maximumZ level are
        // fetched and scaled up for rendering.
        self.animatedTileOverlay = TCCAnimationTileOverlay(templateURLs:pluckedArray, frameDuration:0.5, minimumZ: 3, maximumZ: 9, tileSize: CGSizeMake(256, 256))
        
        self.animatedTileOverlay.delegate = self
        self.mapView.addOverlay(self.animatedTileOverlay, level: .AboveRoads)
        
        self.timeSlider.maximumValue = pluckedArray.count - 1
    }
    
    // MARK: - TCCAnimationTileOverlayDelegate Protocol
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didChangeFromAnimationState previousAnimationState: TCCAnimationState, toAnimationState currentAnimationState: TCCAnimationState) {
        if currentAnimationState == TCCAnimationState.TCCAnimationStateLoading {
            self.startStopButton.setTitle("◼︎", forState: .Normal)
            self.downloadProgressView.hidden = false
        }
        else if currentAnimationState == TCCAnimationState.TCCAnimationStateStopped {
            self.startStopButton.setTitle("▶︎", forState: .Normal)
            self.downloadProgressView.hidden = true
            self.downloadProgressView.progress = 0.0
        }
        else if currentAnimationState == TCCAnimationState.TCCAnimationStateAnimating {
            self.startStopButton.setTitle("❚❚", forState: .Normal)
            self.downloadProgressView.hidden = true
        }
    }
    
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didAnimationWithAnimationFrameIndex animationFrameIndex: Int) {
        // When the animation overlay animates to a new frame, it's the responsibility of the delegate
        // to call setNeedsDisplay
        self.animatedTileRenderer.setNeedsDisplayInMapRect(self.mapView.visibleMapRect)
        
        self.frameIndexLabel.text = "\(animationFrameIndex)"
        if animationTileOverlay.currentAnimationState == TCCAnimationState.TCCAnimationStateAnimating {
            self.timeSlider.value = animationFrameIndex
        }
    }
    
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didHaveError error: NSError) {
        if !self.alertView {
            self.displayError(error)
        }
    }
    
    // MARK: - MKMapViewDelegate Protocol
    func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // When the user moves/zooms/rotates the map, it should pause loading or animating, since
        // otherwise we might not have fetched the tile data necessary to display the overlay
        // for the new region.
        if self.animationTileOverlay.currentAnimationState == TCCAnimationState.TCCAnimationStateAnimating ||
            self.animatedTileOverlay.currentAnimationState == TCCAnimationState.TCCAnimationStateLoading {
                self.animatedTileOverlay.pauseAnimating()
        }
        
        // Disable the slider when the region changes. Only want to enable it until the
        // tiles have finished fetching.
        self.timeSlider.enabled = false
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is TCCAnimationTileOverlay {
            self.animatedTileRenderer = TCCAnimationTileOverlayRenderer(overlay: overlay)
            self.animatedTileRender.drawDebugInfo = true
            self.animatedTileRenderer.alpha = 1.0
            
            return self.animatedTileRenderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
}
