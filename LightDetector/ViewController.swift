//
//  ViewController.swift
//  LightDetector
//
//  Created by David Vieser on 2/11/18.
//  Copyright © 2018 Olivia. All rights reserved.
//

import UIKit
import ImageIO
import AVFoundation

protocol FrameExtractorDelegate: class {
    func captured(image: UIImage)
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var thresholdLabel: UILabel!
    
    @IBOutlet weak var thresholdSlider: UISlider!
    
    private let position = AVCaptureDevice.Position.front
    private let quality = AVCaptureSession.Preset.low
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    
    weak var delegate: FrameExtractorDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermission()
        thresholdLabel.text = "\(thresholdSlider.value)"
        sessionQueue.async { [unowned self] in
            self.configureSession()
            self.captureSession.startRunning()
        }

    }
        
    // MARK: AVSession configuration
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice() else { return }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
    }
    
    private func selectCaptureDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.devices().filter {
            ($0 as AnyObject).hasMediaType(AVMediaType.video) &&
                ($0 as AnyObject).position == position
            }.first as? AVCaptureDevice
    }
    
//    // MARK: Sample buffer to UIImage conversion
//    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
//        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
//        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
//        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
//        return UIImage(cgImage: cgImage)
//    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    

    var playing: Bool = false
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let brightnessValue = getBrightnessValue(from: sampleBuffer)
        print(brightnessValue)
        if brightnessValue < thresholdSlider.value && !playing {
            playing = true
            let systemSoundID: SystemSoundID = 1035
            
            // to play sound
            AudioServicesPlaySystemSoundWithCompletion(systemSoundID, {
                self.playing = false
            })
        }
        
//        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
//        DispatchQueue.main.async { [unowned self] in
//            self.delegate?.captured(image: uiImage)
//        }
    }
    
    func getBrightnessValue(from sampleBuffer: CMSampleBuffer) -> Float {
        guard
            let metadataDict = CMCopyDictionaryOfAttachments(nil, sampleBuffer, kCMAttachmentMode_ShouldPropagate) as? [String: Any],
            let exifMetadata = metadataDict[String(kCGImagePropertyExifDictionary)] as? [String: Any],
            let brightnessValue = exifMetadata[String(kCGImagePropertyExifBrightnessValue)] as? Float
            else { return 0.0 }
        
        return brightnessValue
    }
    
    /*
     - (void)captureOutput:(AVCaptureOutput *)captureOutput
     didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection
     {
     CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,
     sampleBuffer, kCMAttachmentMode_ShouldPropagate);
     NSDictionary *metadata = [[NSMutableDictionary alloc]
     initWithDictionary:(__bridge NSDictionary*)metadataDict];
     CFRelease(metadataDict);
     NSDictionary *exifMetadata = [[metadata
     objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
     float brightnessValue = [[exifMetadata
     objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
     }
     
     // Do any additional setup after loading the view, typically from a nib.
     }
     */

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func thresholdSliderValueChanged(_ sender: Any) {
        thresholdLabel.text = "\(thresholdSlider.value)"
    }
    
}
