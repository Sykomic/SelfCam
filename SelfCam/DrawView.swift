//
//  DrawView.swift
//  SelfCam
//
//  Created by 최대식 on 2022/03/18.
//

import Foundation
import UIKit

class DrawView: UIView {
    var lineArray: [[CGPoint]] = [[CGPoint]]()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let firstPoint = touch.location(in: self)
        lineArray.append([CGPoint]())
        lineArray[lineArray.count - 1].append(firstPoint)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        lineArray[lineArray.count - 1].append(currentPoint)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(5)
        context?.setStrokeColor(UIColor.red.cgColor)
        context?.setLineCap(.round)

        for line in lineArray {
            guard let firstPoint = line.first else { continue }
            context?.beginPath()
            context?.move(to: firstPoint)
            for point in line.dropFirst() {
                context?.addLine(to: point)
            }
            context?.strokePath()
        }
    }
}
