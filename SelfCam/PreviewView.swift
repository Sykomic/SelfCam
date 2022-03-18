//
//  PreviewView.swift
//  SelfCam
//
//  Created by 최대식 on 2022/03/18.
//

import Foundation
import UIKit
import AVFoundation

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    // Convenience wrapper to get layer as its static call
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return self.layer as! AVCaptureVideoPreviewLayer
    }
}
