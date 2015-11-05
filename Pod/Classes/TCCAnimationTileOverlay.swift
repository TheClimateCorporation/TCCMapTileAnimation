//
//  TCCAnimationTileOverlay.swift
//  Pods
//
//  Created by Kiavash Faisali on 11/5/15.
//
//

import UIKit
import MapKit

protocol TCCAnimationTileOverlayDelegate: class {
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didChangeFromAnimationState previousAnimationState: TCCAnimationState, toAnimationState currentAnimationState: TCCAnimationState)
    
    func animationTileOverlay(animationTileOverlay: TCCAnimationTileOverlay, didAnimationWithAnimationFrameIndex animationFrameIndex: Int)
}

enum TCCAnimationState: Int {
    case Stopped = 0
    case Loading
    case Animating
    case Scrubbing
}

enum TCCAnimationTileOverlayError: Int {
    case InvalidZoomLevel = 1001
    case BadURLResponseCode
    case NoImageData
    case NoFrames
}

class TCCAnimationTileOverlay: MKTileOverlay {
    weak var delegate: TCCAnimationTileOverlayDelegate?
    
    var currentFrameIndex: Int
    private(set) var numberOfAnimationFrames: Int
    
    var templateURLs: NSArray {
        // Allows users to mutate the template URLs of the animation overlay.
        willSet {
            self.pauseAnimating()
            self.numberOfAnimationFrames = newValue.count
        }
    }
    
    private var downloadQueue: NSOperationQueue
    private var frameDuration: NSTimeInterval
    private var timer: NSTimer?
    private(set) var currentAnimationState: TCCAnimationState {
        didSet {
            self.delegate?.animationTileOverlay(self, didChangeFromAnimationState: oldValue, toAnimationState: self.currentAnimationState)
        }
    }
    
    private var animationTiles: Set<TCCAnimationTile>
    private var staticTilesCache: NSCache
    private var session: NSURLSession
    
    init(templateURLs: NSArray, frameDuration: NSTimeInterval, minimumZ: NSInteger, maximumZ: NSInteger, tileSize: CGSize) {
        super.init(URLTemplate: nil)
        
        let URLCache = NSURLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 32 * 1024 * 1024, diskPath: nil)
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.URLCache = URLCache
        self.session = NSURLSession(configuration: configuration)
        self.templateURLs = templateURLs
        self.numberOfAnimationFrames = templateURLs.count
        self.frameDuration = frameDuration
        self.currentFrameIndex = 0
        self.downloadQueue = NSOperationQueue()
        self.downloadQueue.maxConcurrentOperationCount = 4
        
        if self.downloadQueue.respondsToSelector("setQualityOfService:") {
            self.downloadQueue.qualityOfService = .UserInitiated
        }
        
        self.currentAnimationState = .Stopped
        
        self.minimumZ = minimumZ
        self.maximumZ = maximumZ
        self.tileSize = tileSize
        
        self.staticTilesCache = NSCache()
    }
    
    // MARK: - MKOverlay
    private func coordinate() -> CLLocationCoordinate2D {
        return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(self.boundingMapRect()), MKMapRectGetMidY(self.boundingMapRect())))
    }

    private func boundingMapRect() -> MKMapRect {
        return MKMapRectWorld
    }
    
    // MARK: - Public
    func startAnimating() {
        // Have to set the current animation state first before firing the timer because the timer depends on
        // the animation state to be animating, otherwise the playback skips one frame of animation.
        
        self.currentAnimationState = .Animating
        self.timer = NSTimer.scheduledTimerWithTimeInterval(self.frameDuration, target: self, selector: "updateAnimationTiles:", userInfo: nil, repeats: true)
        self.timer?.fire()
    }
    
    func pauseAnimating() {
        self.currentAnimationState = .Stopped
        self.timer?.invalidate()
        self.downloadQueue.cancelAllOperations()
        self.timer = nil
    }
    
    func cancelLoading() {
        self.pauseAnimating()
    }
    
    func moveToFrameIndex(frameIndex: NSInteger, isContinuouslyMoving: Bool) {
        
    }
    
    func canAnimateForMapRect(rect: MKMapRect, zoomLevel: NSInteger) {
        
    }
    
    func fetchTilesForMapRect(mapRect: MKMapRect, zoomLevel: Int, progressHandler: ((loadedFrameIndex: Int) -> Void), completionHandler: ((success: Bool, error: NSError?) -> Void)?) {
        if self.templateURLs.count == 0 {
            let error = NSError(domain: ErrorDomain.TCCAnimationTileOverlayErrorDomain, code: TCCAnimationTileOverlayError.NoFrames.rawValue, userInfo: nil)

            completionHandler?(success: false, error: error)

            return
        }

        self.currentAnimationState = .Loading

        // Cap the zoom level of the tiles to fetch if the current zoom scale is not
        // supported by the tile server
        let newZoomLevel = max(min(zoomLevel, self.maximumZ), self.minimumZ)
        
        // Generate list of tiles on the screen to fetch
        self.animationTiles = self.mapTilesInMapRect(mapRect, zoomLevel: zoomLevel)
        
        // Fill in map tiles with an array of template URL strings, one for each frame
        for tile: TCCAnimationTile in self.animationTiles {
            var array = NSMutableArray()
            for (var timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
                array.addObject(self.URLStringForX(tile.x, Y: tile.y, Z: tile.z, timeIndex: timeIndex)
            }
            
            time.templatureURLs = array.copy()
        }
        
        // "Completion" done op - detects when all fetch operations have completed
        let completionDoneOp = NSBlockOperation {
            self.updateAnimationTilesToFrameIndex(self.currentFrameIndex)
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler?(success: true, error: nil)
            }
        }
        
        // Initiate fetch operations for tiles for each frame
        var operations = [NSOperation]()
        let previousDoneOp: NSOperation
        
        for (var frameIndex = 0; frameIndex < self.numberOfAnimationFrames; frameIndex++) {
            // Create "Done" operation for this animation frame -- need this to signal when
            // all tiles for this frame have finished downloading so we can fire progress handler
            let doneOp = NSBlockOperation {
                dispatch_async(dispatch_get_main_queue()) {
                    progressHandler(loadedFrameIndex: frameIndex)
                }
            }
            
            // Fetch and cache the tile data
            for (tile: TCCAnimationTile in self.animationTiles) {
                // Create NSOperation to fetch tile
                let fetchOp = TCCTileFetchOperation(title: title, frameIndex: frameIndex)
                
                // Add a dependency from the "Done" operation onto this operation
                doneOp.addDependency(fetchOp)
                
                // Queue it onto the download queue
                operations.addObject(fetchOp)
            }
            
            // Queue the "Done" operation
            operations.append(doneOp)
            completionDoneOp.addDependency(doneOp)
            
            // The "Done" operations for each frame should also have a dependency on the previous done op.
            // This prevents the case where the loading progress can go from 2 to 4 back to 3 then to 5, etc.
            doneOp.addDependency(previousDoneOp)
            previousDoneOp = doneOp
        }
        
        operations.append(completionDoneOp)
        self.downloadQueue.addOperations(operations, waitUntilFinished: false)
    }
    
    func moveToFrameIndex(frameIndex: Int, isContinuouslyMoving: Bool) {
        if (self.currentAnimationState == .Animating) {
            self.pauseAnimating()
        }
        
        // If the user is scrubbing (i.e. continually moving), update the animation tiles' images to
        // the desired frame index, since the animation tiles are the ones that are rendered. If the
        // user has finished scrubbing, the renderer uses the static tiles to render
        if isContinuouslyMoving {
            // Need to set the animation state to "scrubbing". This is because the animation renderer
            // uses two different method of retrieving tiles based on whether the current animation state
            // of the overlay is stopped (uses static tiles with async loadTileAtPath) or scrubbing/animating
            // (uses cached animation tiles synchronously). If we don't set this to scrubbing and let it
            // be stopped, the rendering has a noticeable flicker due to the async nature of loading tiles.
            self.currentAnimationState = .Scrubbing
            self.updateAnimationTilesToFrameIndex(frameIndex)
            
            // We're actively scrubbing, so there's a good chance that the static tiles in the cache
            // will not be used.
            self.staticTilesCache.removeAllObjects()
            
            self.delegate?.animationTileOverlay(self, didAnimationWithAnimationFrameIndex: self.currentFrameIndex)
        }
        else {
            self.currentAnimationState = .Stopped
        }
    }
    
    func animationTileForMapRect(mapRect: MKMapRect, zoomLevel: Int) -> TCCAnimationTile {
        let path = TCCMapKitHelpers.tilePathForMapRect(mapRect, zoomLevel: zoomLevel)
        let tile = TCCAnimationTile(frame: mapRect, x: path.x, y: path.y, z: path.z)
        
        return self.animationTiles.member(tile)
    }
    
    func staticTileForMapRect(mapRect: MKMapRect, zoomLevel: Int) -> TCCAnimationTile {
        let path = TCCMapKitHelpers.tilePathForMapRect(mapRect, zoomLevel: zoomLevel)
        let cappedMapRect = TCCMapKitHelpers.mapRectForTilePath(path)
        
        let tile = self.staticTilesCache.objectForKey(self.keyForTilePath(path))
        
        if tile != nil && tile.tileImageIndex == self.currentFrameIndex {
            return tile
        }
        
        if tile == nil {
            tile = TCCAnimationTile(frame: cappedMapRect, x: path.x, y: path.y, z: path.z)
        }
        
        tile.tileImage = nil
        
        var array = NSMutableArray()
        for (var timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
            array.addObject(self.URLStringForX(tile.x, Y: tile.y, Z: tile.z, timeIndex: timeIndex)
        }
        
        tile.templateURLs = array.copy()
        
        self.staticTilesCache.setObject(tile, forKey: "\(tile.x)-\(tile.y)-\(tile.z)")
        
        return tile
    }
    
    func cachedTilesForMapRect(rect: MKMapRect, zoomLevel: Int) -> [TCCAnimationTile] {
        var tiles = [TCCAnimationTile]()
        for (tile in self.animationTiles) {
            if MKMapRectIntersectsRect(rect, tile.mapRectFrame) && tile.z == zoomLevel {
                tiles.append(tile)
            }
        }
        
        return tiles
    }
    
    func cachedStaticTilesForMapRect(rect: MKMapRect, zoomLevel: Int) -> [TCCAnimationTile] {
        var tiles = [TCCAnimationTile]()
        
        let tilesInMapRect = self.mapTilesInMapRect(rect, zoomLevel: zoomLevel)
        for (tile in tilesInMapRect) {
            let cachedTile = self.staticTilesCache.objectForKey(self.keyForTile(tile))
            // The cache should always contain a tile, but in the event of an unexpected cache miss (i.e.
            // the app cleared the cache right before we needed it, which it shouldn't do), we opt to not
            // return the tile since inserting nil would cause a crash
            if cachedTile == nil {
                continue
            }
            
            if MKMapRectIntersectsRect(rect, tile.mapRectFrame) {
                tiles.append(cachedTile)
            }
        }
        
        return tiles
    }
    
    func canAnimateForMap(rect: MKMapRect, zoomLevel: Int) {
        let visibleMapTiles = self.mapTilesInMapRect(rect, zoomLevel: zoomLevel)
        for visibleTile in visibleMapTiles {
            if self.animationTiles.containsObject(visibleTile) == false {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Overrides
    override func loadTileAtPath(path: MKTileOverlayPath, result: (NSData?, NSError?) -> Void) {
        let tile = self.staticTilesCache.objectForKey(self.keyForTilePath(path))
        
        let url = NSURL(string: tile.templateURLs[self.currentFrameIndex])
        tile.tileImageIndex = self.currentFrameIndex
        
        let request = NSURLRequest(URL: url, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 0)
        
        let task = self.session.dataTaskWithRequest(request) { (data, response, error) in
            if data != nil && error == nil {
                tile.tileImage = UIImage(data: data)
            }
            
            result(data, error)
        }
        
        task.resume()
    }
    
    // MARK: - Private
    func updateAnimationTilesToFrameIndex(frameIndex: Int) {
        // The tiles in self.animationTiles need tileImage to be updated to the frameIndex.
        // TCCTileFetchOperation does this for us. We want to block until all tiles have
        // been updated. In theory, the NSURLCache used by NSURLSession should already have
        // all the necessary tile image data from fetchTilesForMapRect:
        var operations = [NSOperation]()
        for tile in self.animationTiles {
            if tile.failedToFetch {
                continue
            }
            
            let fetchOp = TCCTileFetchOperation(tile: tile, frameIndex: frameIndex)
            fetchOp.completionBlock = {
                [weak fetchOp] in
                
                tile.tileImage = fetchOp?.tileImage
                tile.failedToFetch = (tile.tileImage == nil)
            }
            
            operations.append(fetchOp)
        }
        
        self.downloadQueue.addOperations(operations, waitUntilFinished: true)
        
        self.currentFrameIndex = frameIndex
        if self.currentAnimationState == .Animating {
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.animationTileOverlay(self, didAnimationWithAnimationFrameIndex: self.currentFrameIndex)
            }
        }
    }
    
    // Derives a URL string from the template URLs, needs tile coordinates and a time index
    func URLStringForX(xValue: Int, Y yValue: Int, Z zValue: Int, timeIndex aTimeIndex: Int) -> String {
        let currentTemplateURL = self.templateURLs[aTimeIndex]
        let xString = "\(xValue)"
        let yString = "\(yValue)"
        let zString = "\(zValue)"
        
        let replaceX = currentTemplateURL.stringByReplacingOccurencesOfString(Index.X_INDEX, withString: xString)
        let replaceY = replaceX.stringByReplacingOccurencesOfString(Index.Y_INDEX, withString: yString)
        let replaceZ = replaceY.stringByReplacingOccurencesOfString(Index.Z_INDEX, withString: zString)
        
        let returnString = replaceZ
        
        return returnString
    }
    
    // Creates a set of @c MATAnimationTile objects for a given map rect and zoom scale
    func mapTilesInmapRect(rect: MKMapRect, var zoomLevel: Int) -> NSSet {
        var overZoom = 1
        
        if zoomLevel > self.maximumZ {
            overZoom = pow(2, (zoomLevel - self.maximumZ))
            zoomLevel = self.maximumZ
        }
        
        // When we are zoomed in beyond the tile set, use the tiles from the maximum z-depth,
        // but render them larger.
        // **Adjusted from overZoom * self.tileSize to just self.tileSize in order to render at overzoom properly
        let adjustedTileSize = self.tileSize.width
        
        // Need to use the zoom level zoom scale, not the actual zoom scale from the map view!
        let zoomExponent = 20 - zoomLevel
        let zoomScale = 1/pow(2, zoomExponent)
        
        let minX = floor((MKMapRectGetMinX(rect) * zoomScale) / adjustedTileSize)
        let maxX = ceil((MKMapRectGetMaxX(rect) * zoomScale) / adjustedTileSize)
        let minY = floor((MKMapRectGetMinY(rect) * zoomScale) / adjustedTileSize)
        let maxY = ceil((MKMapRectGetMaxY(rect) * zoomScale) / adjustedTileSize)
        
        var tiles = NSMutableSet()
        for (var x = minX; x <= maxX; x++) {
            for (var y = minY; y <= maxY; y++) {
                let frame = MKMapRectMake((x * adjustedTileSize) / zoomScale, (y * adjustedTileSize) / zoomScale, adjustedTileSize / zoomScale, adjustedTileSize / zoomScale)
                
                if MKMapRectIntersectsRect(frame, rect) {
                    let tile = TCCAnimationTile(frame: frame, x: x, y: y, z: zoomLevel)
                    tiles.addObject(tile)
                }
            }
        }
        
        return tiles.copy()
    }
    
    func checkResponseForError(response: NSHTTPURLResponse, data: NSData?) -> Bool {
        if data != nil {
            if response.statusCode != 200 {
                let localizedDescription = "Error during fetch. Image tile HTTP response code \(response.statusCode), URL \(response.URL)"
                
                let error = NSError(domain: ErrorDomain.TCCAnimationTileOverlayErrorDomain, code: TCCAnimationTileOverlayError.BadURLResponseCode.rawValue, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
                
                self.sendErrorToDelegate(error)
                
                return true
            }
        }
        else {
            let localizedDescription = "No image data. HTTP response code \(response.statusCode), URL \(response.URL)"
            let error = NSError(domain: ErrorDomain.TCCAnimationTileOverlayErrorDomain, code: TCCAnimationTileOverlayError.NoImageData.rawValue, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
            
            self.sendErrorToDelegate(error)
            
            return true
        }
        
        return false
    }
    
    func sendErrorToDelegate(error: NSError) {
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.animationTileOverlay(self, didHaveError: error)
        }
    }
    
    func keyForTilePath(path: MKTileOverlayPath) -> String {
        return "\(path.x)-\(path.y)-\(path.z)"
    }
    
    func keyForTile(tile: TCCAnimationTile) -> String {
        return "\(tile.x)-\(tile.y)-\(tile.z)"
    }
}
