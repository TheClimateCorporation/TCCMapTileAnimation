//
//  TCCAnimationTile.swift
//  Pods
//
//  Created by Kiavash Faisali on 11/5/15.
//
//

import UIKit

class TCCAnimationTile: NSObject {
    var x: Int
    var y: Int
    var z: Int
    var mapRectFrame: MKMapRect
    var tileImage: UIImage
    var tileImageIndex: Int
    var templateURLs: [String]
    var failedToFetch: Bool
    
    init(frame: MKMapRect, x: Int, y: Int, z: Int) {
        super.init()
        
        self.x = x
        self.y = y
        self.z = z
        self.mapRectFrame = frame
    }
    
    // MARK: - Public Methods
    func description() -> String {
        return "(\(self.x), \(self.y), \(self.z)) mapRectFrame origin: (\(self.mapRectFrame.origin.x), \(self.mapRectFrame.origin.y) size: (\(self.mapRectFrame.size.width), \(self.mapRectFrame.size.height))"
    }
    
    // MARK: - Overridden Methods
    func isEqual(object: AnyObject) -> Bool {
        if !(object is TCCAnimationTile) {
            return false
        }
        
        let other = object as! TCCAnimationTile
        return self.hash() == other.hash() &&
                self.x == other.x &&
                self.y == other.y &&
                self.z == other.z
    }
    
    func hash() -> Int {
        return "\(self.x)/\(self.y)/\(self.z)"
    }
}
