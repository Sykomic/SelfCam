//
//  Classifier.swift
//  SelfCam
//
//  Created by 최대식 on 2022/03/18.
//

import Foundation
import Vision

class Classifier {
    var model: VNCoreMLModel!
    
    func createImageClassifier() {
        do {
            let imageClassifier = try CNNEmotions(configuration: MLModelConfiguration())
            let imageClassifierModel = imageClassifier.model
            do {
                let imageClassifierVisionModel = try VNCoreMLModel(for: imageClassifierModel)
                self.model = imageClassifierVisionModel
            } catch {
                print(error)
            }
        } catch {
            print(error)
        }
    }
    
    init() {
        createImageClassifier()
    }
}
