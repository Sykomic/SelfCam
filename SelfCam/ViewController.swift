//
//  ViewController.swift
//  SelfCam
//
//  Created by 최대식 on 2022/03/18.
//

import UIKit
import Vision
import SnapKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    var captureSession: AVCaptureSession!
    var previewView: PreviewView!
    var captureButton: UIButton!
    var outerCircle: UIView!
    var catImage: UIImage?
    var faceBox: CGRect?
    var buffer: CMSampleBuffer?
    var detectedFaceRectangleShapeLayer: [CAShapeLayer]?
    var detectedFaceLandmarksShapeLayer: [CAShapeLayer]?
    var emotionTextLayer: [CATextLayer]?
    var cuteCatLayer: [CALayer]?
    var classifierModel: VNCoreMLModel = Classifier().model
    var isFaceDetected: Bool = false {
        didSet {
            if isFaceDetected {
                captureButton.isHidden = false
                outerCircle.isHidden = false
            } else {
                captureButton.isHidden = true
                outerCircle.isHidden = true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.requestCameraAuthorization()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.requestCatImage()
        
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            print("authorized")
            self.captureSession.startRunning()
        }
    }
    
    @objc func touchUpCameraCaptureButton(_ sender: UIButton) {
        print("captured")
        
         PHPhotoLibrary.requestAuthorization { status in
             guard status == .authorized else { return }
             
         }

        self.capturePhoto()
    }
    
    func setupCameraPreviewView() {
        self.previewView = PreviewView()
        self.previewView.videoPreviewLayer.session = self.captureSession
        self.view.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }
        self.captureSession.startRunning()
    }

    func setCaptureButton(tintColor: UIColor) {
        self.outerCircle = UIView()
        let outerCircleImage = UIImageView(image: UIImage(systemName: "circle")?.withTintColor(tintColor, renderingMode: .alwaysOriginal))
        self.outerCircle.addSubview(outerCircleImage)
        outerCircleImage.snp.makeConstraints { make in
            make.edges.equalTo(self.outerCircle)
        }
        self.outerCircle.isHidden = true
        self.view.addSubview(outerCircle)
        self.outerCircle.snp.makeConstraints { make in
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
            make.centerX.equalTo(self.view.snp.centerX)
            make.size.equalTo(100)
        }
        
        self.captureButton = UIButton()
        self.captureButton.setImage(UIImage(systemName: "circle.fill")?.withTintColor(tintColor, renderingMode: .alwaysOriginal), for: .normal)
        self.captureButton.addTarget(self, action: #selector(self.touchUpCameraCaptureButton(_:)), for: .touchUpInside)
        self.captureButton.imageView?.snp.makeConstraints({ make in
            make.size.equalToSuperview()
        })
        self.outerCircle.addSubview(captureButton)
        self.captureButton.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
    }
    
    func capturePhoto() {
        let photoSettings: AVCapturePhotoSettings
        let photoOutput: AVCapturePhotoOutput = self.captureSession.outputs.first { output in
            guard output is AVCapturePhotoOutput else {
               return false
            }
            return true
        } as! AVCapturePhotoOutput
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            photoSettings = AVCapturePhotoSettings()
        }
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func drawLayer(landmarkRegion: VNFaceLandmarkRegion2D, path: CGMutablePath, transform: CGRect) -> CAShapeLayer {
        let pointCount = landmarkRegion.pointCount
        if pointCount > 1 {
            let points: [CGPoint] = landmarkRegion.normalizedPoints.map { point in
                CGPoint(x: point.y * transform.height + transform.origin.x, y: point.x * transform.width + transform.origin.y)
            }
            path.addLines(between: points)
        }
        
        let drawing = CAShapeLayer()
        drawing.path = path
        drawing.fillColor = UIColor.clear.cgColor
        drawing.strokeColor = UIColor.red.cgColor
        
        return drawing
    }
    
    func drawFaceLandmarks(_ landmarks: VNFaceLandmarks2D, screenBoundingBox: CGRect, faceLandmarksPath: CGMutablePath) -> [CAShapeLayer] {
        var faceLandmarksDrawings: [CAShapeLayer] = []
    
        let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
            landmarks.leftEyebrow,
            landmarks.rightEyebrow,
            landmarks.faceContour,
            landmarks.nose,
            landmarks.medianLine,
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.outerLips,
            landmarks.innerLips,
        ]
        for openLandmarkRegion in openLandmarkRegions {
            faceLandmarksDrawings.append(self.drawLayer(landmarkRegion: openLandmarkRegion!, path: faceLandmarksPath, transform: screenBoundingBox))
        }
        return faceLandmarksDrawings
    }
    
    func clearDrawings() {
        self.emotionTextLayer?.forEach({ text in
            text.removeFromSuperlayer()
        })
        self.detectedFaceRectangleShapeLayer?.forEach({ drawing in
            drawing.removeFromSuperlayer()
        })
        self.detectedFaceLandmarksShapeLayer?.forEach({ drawing in
            drawing.removeFromSuperlayer()
        })
        self.cuteCatLayer?.forEach({ cat in
            cat.removeFromSuperlayer()
        })
    }
    
    func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        // clear drawing
        self.clearDrawings()
        
        var faceLandmarkDraws = [CAShapeLayer]()
        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.flatMap({(observedFace: VNFaceObservation) -> [CAShapeLayer] in
            let faceBoundingBoxOnScreen = self.previewView.videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            self.faceBox = faceBoundingBoxOnScreen

            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            let faceBoundingBoxShape = CAShapeLayer()
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.black.cgColor
            
            if let landmarks = observedFace.landmarks {
                faceLandmarkDraws += self.drawFaceLandmarks(landmarks, screenBoundingBox: faceBoundingBoxOnScreen, faceLandmarksPath: CGMutablePath())
            }
            
            return [faceBoundingBoxShape]
        })
        
        facesBoundingBoxes.forEach { faceBoundingBox in
            self.view.layer.addSublayer(faceBoundingBox)
        }
        
        faceLandmarkDraws.forEach { faceLandmarkDraw in
            self.view.layer.addSublayer(faceLandmarkDraw)
        }
        
        self.detectedFaceRectangleShapeLayer = facesBoundingBoxes
        self.detectedFaceLandmarksShapeLayer = faceLandmarkDraws
    }
    
    func setupCaptureSession() {
        self.captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        // Add device input
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTripleCamera, .builtInTrueDepthCamera, .builtInTelephotoCamera, .builtInDualWideCamera], mediaType: .video, position: .front)
        guard !discoverySession.devices.isEmpty else  { fatalError("Missing capture devices.")}
        let videoDevice = discoverySession.devices.first
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!), captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        // Add video data output
        let videoDataOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        let videoDataOutputQueue = DispatchQueue(label: "Moais")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        guard captureSession.canAddOutput(videoDataOutput) else { return }
        captureSession.addOutput(videoDataOutput)
        guard let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
        
        // Add photo output
        let photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.sessionPreset = .photo
        captureSession.addOutput(photoOutput)
        
        captureSession.commitConfiguration()
    }
    
    func requestCatImage() {
        let session: URLSession = URLSession(configuration: .default)
        let url = URL(string: "https://api.thecatapi.com/v1/images/search?mime_types=jpg,png")
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        request.setValue("bde62bf4-26bf-4ce1-878a-a3906479a527", forHTTPHeaderField: "x-api-key")

        DispatchQueue.global().async {
            let dataTask: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                guard let data = data else { return }
                do {
                    let apiResponse: [APIResponse] = try JSONDecoder().decode([APIResponse].self, from: data)
                    let catUrl: URL = URL(string: apiResponse.first!.url)!
                    
                    do {
                        let data: Data = try Data(contentsOf: catUrl)
                        self.catImage = UIImage(data: data)!
                    } catch (let err) {
                        print(err.localizedDescription)
                    }
                } catch (let err) {
                    print(err.localizedDescription)
                }
            }
            dataTask.resume()
        }
    }
    
    func requestCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("authorized")
            self.view.backgroundColor = .black
            
            self.setupCaptureSession()
            self.setupCameraPreviewView()
            self.setCaptureButton(tintColor: .white)
            
        case .notDetermined:
            print("not determined")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else {
                    print("not granted")
                    return
                }
                DispatchQueue.main.async {
                    self.view.backgroundColor = .black
                    
                    self.setupCaptureSession()
                    self.setupCameraPreviewView()
                    self.setCaptureButton(tintColor: .white)
                    
                }
            }
        case .denied:
            print("denied")
            
        case .restricted:
            print("restricted")
            
        @unknown default:
            print("unknown case")
        }
    }
    
    func classifyEmotion(image: CMSampleBuffer) {
        try? VNImageRequestHandler(cmSampleBuffer: image, orientation: .leftMirrored, options: [:]).perform([VNCoreMLRequest(model: self.classifierModel, completionHandler: { [weak self] request, error in
            guard let emotionResults = request.results as? [VNClassificationObservation] else { return }
            let newEmotion = emotionResults.max { a, b in
                a.confidence < b.confidence
            }
            self?.drawEmotionText(emotion: newEmotion?.identifier)
        })])
    }
    
    func drawEmotionText(emotion: String?) {
        let emotionText = CATextLayer()
        emotionText.frame = self.faceBox!
        emotionText.frame.origin.y -= 50
        emotionText.alignmentMode = .center
        emotionText.string = emotion
        
        if emotion == "Sad" {
            print("sad")
            let catLayer = CALayer()
            catLayer.frame = self.faceBox!
            catLayer.contents = self.catImage?.cgImage
            self.cuteCatLayer = [catLayer]
            self.view.layer.addSublayer(catLayer)
        }
        self.emotionTextLayer = [emotionText]
        self.view.layer.addSublayer(emotionText)
    }
    
    func detectFace(in image: CMSampleBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { request, error in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation], results.count > 0 {
                    print("detected a face.")
                    self.isFaceDetected = true
                    self.handleFaceDetectionResults(results)
                    self.classifyEmotion(image: image)
                } else {
                    print("did not detect any face.")
                    self.isFaceDetected = false
                    self.clearDrawings()
                }
            }
        }
        
        let imageRequestHandler = VNImageRequestHandler(cmSampleBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        DispatchQueue.main.async {
            self.captureSession.stopRunning()
            let editVC: EditViewController = EditViewController()
            editVC.photo = photo
            editVC.faceBox = self.faceBox
            editVC.modalPresentationStyle = .fullScreen
            self.present(editVC, animated: true, completion: nil)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.detectFace(in: sampleBuffer)
        self.buffer = sampleBuffer
    }
}


