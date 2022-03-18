//
//  EditViewController.swift
//  SelfCam
//
//  Created by 최대식 on 2022/03/18.
//

import UIKit
import SnapKit
import Photos

class EditViewController: UIViewController {
    var drawView: DrawView?
    var photoView: UIImageView = UIImageView()
    var photo: AVCapturePhoto?
    var facePhoto: CGImage?
    var faceBox: CGRect?
    var onlyFaceButton: UIButton?
    var fullImageButton: UIButton?
    var drawButton: UIButton?
    var isOnlyFace: Bool = false
    var isDrawing: Bool = false {
        didSet {
            if isDrawing {
                self.onlyFaceButton!.isHidden = true
                self.fullImageButton!.isHidden = true
                self.drawButton!.isHidden = true
            } else {
                self.onlyFaceButton!.isHidden = false
                self.fullImageButton!.isHidden = false
                self.drawButton!.isHidden = false
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.setPhotoView()
        self.setButtons()
        self.cropFace()
    }
    
    @objc func touchUpCancelButton(_ sender: UIButton) {
        print("cancel")
        // do not save to photo library
        if self.isDrawing {
            // clear all drawings.
            self.drawView?.removeFromSuperview()
            self.drawView = nil
            self.isDrawing = false
        } else {
            self.dismiss(animated: true)
        }
    }
    
    @objc func touchUpConfirmButton(_ sender: UIButton) {
        print("confirm")
        // save to photo library
        self.isDrawing = false
        self.requestPhotoLibraryAuthorization()
        
        PHPhotoLibrary.shared().performChanges {
            // Add the captured photo's file data as the main resource for the Photos asset.
            let creationRequest = PHAssetCreationRequest.forAsset()
            var image = UIImage()
            DispatchQueue.main.sync {
                UIGraphicsBeginImageContext(self.view.frame.size)
                self.view.layer.render(in: UIGraphicsGetCurrentContext()!)
                image = UIGraphicsGetImageFromCurrentImageContext()!
                let cgImage = image.cgImage?.cropping(to: self.photoView.frame)
                image = UIImage(cgImage: cgImage!)
                UIGraphicsEndImageContext()
            }
            creationRequest.addResource(with: .photo, data: UIImage.pngData(image)()!, options: nil)
        } completionHandler: { success, error in
            if !success {
                print(error!)
            }
        }

        self.dismiss(animated: true)
    }
    
    @objc func touchUpFullImageButton(_ sender: UIButton) {
        print("showFullImage")
        self.isOnlyFace = false
        photoView.image = UIImage(cgImage: (self.photo?.cgImageRepresentation())!, scale: 1, orientation: .leftMirrored)
        fullImageButton?.isSelected = true
        onlyFaceButton?.isSelected = false
    }
    
    @objc func touchUpOnlyFaceButton(_ sender: UIButton) {
        print("showOnlyFace")
        self.isOnlyFace = true
        self.photoView.image = UIImage(cgImage: self.facePhoto!, scale: 1, orientation: .leftMirrored)
        fullImageButton?.isSelected = false
        onlyFaceButton?.isSelected = true
    }
    
    @objc func touchUpDrawButton(_ sender: UIButton) {
        print("draw")
        self.isDrawing = true
        self.setDrawView()
    }
    
    func setButtons() {
        setCancelButton()
        setConfirmButton()
        self.fullImageButton = setFullImageButton()
        self.onlyFaceButton = setOnlyFaceButton()
        self.drawButton = setDrawButton()
    }
    
    func setCancelButton() {
        let cancelButton: UIButton = UIButton()
        cancelButton.setTitle("취소", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(self.touchUpCancelButton(_:)), for: .touchUpInside)
        self.view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.left)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    func setConfirmButton() {
        let confirmButton: UIButton = UIButton()
        confirmButton.setTitle("완료", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.addTarget(self, action: #selector(self.touchUpConfirmButton(_:)), for: .touchUpInside)
        self.view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    func setFullImageButton() -> UIButton {
        let fullImageButton: UIButton = UIButton()
        fullImageButton.setImage(UIImage(systemName: "photo")?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal), for: .normal)
        fullImageButton.setImage(UIImage(systemName: "photo")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .selected)
        fullImageButton.isSelected = true
        fullImageButton.addTarget(self, action: #selector(self.touchUpFullImageButton(_:)), for: .touchUpInside)
        self.view.addSubview(fullImageButton)
        fullImageButton.imageView?.snp.makeConstraints({ make in
            make.size.equalToSuperview()
        })
        fullImageButton.snp.makeConstraints { make in
            make.right.equalTo(self.view.snp.centerX).offset(-10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.size.equalTo(30)
        }
        return fullImageButton
    }
    
    func setOnlyFaceButton() -> UIButton {
        let onlyFaceButton: UIButton = UIButton()
        onlyFaceButton.setImage(UIImage(systemName: "face.dashed")?.withTintColor(.systemGray4, renderingMode: .alwaysOriginal), for: .normal)
        onlyFaceButton.setImage(UIImage(systemName: "face.dashed")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .selected)
        
        onlyFaceButton.addTarget(self, action: #selector(self.touchUpOnlyFaceButton(_:)), for: .touchUpInside)
        self.view.addSubview(onlyFaceButton)
        onlyFaceButton.imageView?.snp.makeConstraints({ make in
            make.size.equalToSuperview()
        })
        onlyFaceButton.snp.makeConstraints { make in
            make.left.equalTo(self.view.snp.centerX).offset(10)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.size.equalTo(30)
        }
        return onlyFaceButton
    }
    
    func setDrawButton() -> UIButton {
        let drawButton: UIButton = UIButton()
        drawButton.setImage(UIImage(systemName: "pencil.tip.crop.circle"), for: .normal)
        drawButton.tintColor = .systemGray4
        drawButton.addTarget(self, action: #selector(self.touchUpDrawButton(_:)), for: .touchUpInside)
        self.view.addSubview(drawButton)
        drawButton.imageView?.snp.makeConstraints({ make in
            make.size.equalToSuperview()
        })
        drawButton.snp.makeConstraints { make in
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.right)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.size.equalTo(30)
        }
        return drawButton
    }
    
    func setPhotoView() {
        self.view.backgroundColor = .black
        photoView.contentMode = .scaleAspectFill
        photoView.image = UIImage(cgImage: (self.photo?.cgImageRepresentation())!, scale: 1, orientation: .leftMirrored)
        self.view.addSubview(photoView)
        photoView.snp.makeConstraints { make in
            make.leading.equalTo(self.view.snp.leading)
            make.trailing.equalTo(self.view.snp.trailing)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).inset(50)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).inset(50)
        }
    }
    
    func setDrawView() {
        self.drawView = DrawView()
        drawView!.backgroundColor = .clear
        self.view.addSubview(drawView!)
        drawView!.snp.makeConstraints { make in
            make.edges.equalTo(self.photoView.snp.edges)
        }
    }
    
    func cropFace() {
        let cgImage = self.photo?.cgImageRepresentation()
        let uiImage = UIImage(cgImage: cgImage!, scale: 1, orientation: .leftMirrored)
        let viewWidth = self.view.frame.width
        let viewHeight = self.view.frame.height
        let widthRatio = uiImage.size.width / viewWidth
        let heightRatio = uiImage.size.height / viewHeight
        // UIImage에서 CGImage로 바꾸면 다시 오리엔테이션이 바뀜 -> 그에 맞춰 x, y 값을 서로 바꿔주면 됨.
        let newRect = CGRect(x: self.faceBox!.origin.y * heightRatio - 100 * heightRatio, y: self.faceBox!.origin.x * widthRatio, width: self.faceBox!.size.height * heightRatio + 200 * heightRatio, height: self.faceBox!.size.width * widthRatio)
        let croppedCgImage = uiImage.cgImage!.cropping(to: newRect)
        self.facePhoto = croppedCgImage
    }

    func requestPhotoLibraryAuthorization() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            print("authorized")
        case .notDetermined:
            print("not determined")
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    print("granted")
                } else {
                    print("not granted")
                }
            }
        case .denied:
            print("denined")
        case .restricted:
            print("restricted")
        case .limited:
            print("limited")
        @unknown default:
            print("unknown case")
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
