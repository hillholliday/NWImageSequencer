//
//  NWImageSequencer.swift
//
//  Created by Nat on 12/3/15.
//

import Foundation
import UIKit
import AssetsLibrary
import Photos
import AVFoundation

//MARK: Public
public typealias SuccessHandler = (_ movieUrl: URL) -> Void
public typealias ErrorHandler = (_ error: Error) -> Void
public typealias ProgressHandler = (_ progress:Float) ->Void
public typealias PHSaveSuccessHandler = (_ asset: PHAsset) -> Void

//MARK: Private

private let NWImageSequencerErrorDomain = "NWImageSequencerErrorDomain"

private enum PixelBufferError: Error {
    case NullBufferError
    case NullContextError
    case NullColorSpaceError
}

private enum PathError : Error {
    case NullPathError
}

public struct NWImageSequencer {
    
    private static func pixelBufferFromCGImage(cgImage:CGImage, widthSourceSize size:CGSize) throws -> CVPixelBuffer {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let options = [
            kCVPixelBufferCGImageCompatibilityKey : true,
            kCVPixelBufferCGBitmapContextCompatibilityKey : true
        ] as CFDictionary
        
        var pxBuffer:CVPixelBuffer? = nil
        let status:CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options, &pxBuffer)
        
        guard let buffer = pxBuffer, status == kCVReturnSuccess else {
            throw PixelBufferError.NullColorSpaceError
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pxData = CVPixelBufferGetBaseAddress(buffer)
        
        guard let context = CGContext.init(data: pxData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            throw PixelBufferError.NullContextError
        }
        
        context.concatenate(CGAffineTransform.init(rotationAngle: 0))
        
        context.draw(cgImage, in: CGRect.init(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return buffer
    }
    
    private static func getLargestSizeToContainImages(images:[UIImage]) -> CGSize {
        var height:CGFloat = 0.0
        var width:CGFloat = 0.0
        for image in images {
            if image.size.width > width {
                width = image.size.width
            }
            
            if image.size.height > height {
                height = image.size.height
            }
        }
        return CGSize(width: width, height: height)
    }
    
    public static func createLocalMovieWithImages(images:[UIImage], options: NWImageSequencerOptions, onSuccess:SuccessHandler?, onError: ErrorHandler?, onProgress: ProgressHandler?) {
        
        let path = getLocalPath(path: options.localPath)
        let tempURL = URL.init(fileURLWithPath: path)
        let manager = FileManager.default
        try? manager.removeItem(at: tempURL)
        
        let url = URL.init(fileURLWithPath: path)
        let movieWriter:AVAssetWriter
        
        do{
            movieWriter = try AVAssetWriter.init(outputURL: url, fileType: options.fileType)
        } catch let error {
            onError?(error)
            return
        }
        
        let sourceSize = NWImageSequencer.getLargestSizeToContainImages(images: images)
        let outputSettings:[String:Any] = [
            AVVideoCodecKey: AVVideoCodecH264 as AnyObject,
            AVVideoWidthKey: Int(options.outputSize.width),
            AVVideoHeightKey: Int(options.outputSize.height)
        ]
        let movieWriterInput = AVAssetWriterInput.init(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: movieWriterInput, sourcePixelBufferAttributes: nil)
        movieWriter.add(movieWriterInput)
        movieWriter.startWriting()
        movieWriter.startSession(atSourceTime: kCMTimeZero)
        
        var buffer:CVPixelBuffer? = nil
        
        var i = 0
        let ticSize:Int64 = Int64(round(600 / options.secondsPerImage))
        
        while(true) {
            if(movieWriterInput.isReadyForMoreMediaData) {
                
                let frameTime = CMTimeMake(ticSize, 600)
                let lastTime = CMTimeMake(Int64(i)*ticSize, 600)
                var presentTime = CMTimeAdd(lastTime, frameTime)
                
                if(i==0) {
                    presentTime = CMTimeMake(0,600)
                }
                
                if(i >= images.count) {
                    buffer = nil
                } else {
                    do {
                        try buffer = NWImageSequencer.pixelBufferFromCGImage(cgImage: images[i].cgImage!, widthSourceSize: sourceSize)
                    } catch let error {
                        onError?(error)
                        return
                    }
                }
                
                if let buffer = buffer {
                    pixelBufferAdaptor.append(buffer, withPresentationTime: presentTime)
                    i = i + 1 //wtf can't I do i++?
                    let prog = Float(i)/Float(images.count)
                    onProgress?(prog)
                } else {
                    movieWriter.finishWriting(completionHandler: {
                        if(movieWriter.status == AVAssetWriterStatus.completed) {
                            let tempURL = URL.init(fileURLWithPath: path)
                            onSuccess?(tempURL)
                            return
                        } else {
                            let error = movieWriter.error ?? NSError()
                            onError?(error)
                            return
                        }
                    })
                    break;
                }
            }
        }
    }
    
    public static func saveMovieAtUrl(url:URL, toAlbumNamed albumName:String, onSaveSuccess:PHSaveSuccessHandler?, onError:ErrorHandler?) {
        let fetchOptions = PHFetchOptions()
        var placeHolder:PHObjectPlaceholder? = nil
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject
        
        if collection == nil {
            PHPhotoLibrary.shared().performChanges({
                let createAlbum = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                placeHolder = createAlbum.placeholderForCreatedAssetCollection
            }, completionHandler: { (success, error) in
                if success == true && placeHolder != nil {
                    let collectionFetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeHolder!.localIdentifier], options: nil)
                    if let assetCollection:PHAssetCollection = collectionFetchResult.firstObject {
                        self.saveMovieToCollection(collection: assetCollection, withURL: url, onSaveSuccess: onSaveSuccess, onError: onError)
                        return
                    } else {
                        print("failed to save move to camera roll as assetCollection was unexpectedly nil")
                    }
                }
                let error = error ?? NSError()
                onError?(error)
            })
        } else {
            saveMovieToCollection(collection: collection! , withURL: url, onSaveSuccess: onSaveSuccess, onError: onError)
        }
    }
    
    private static func saveMovieToCollection(collection:PHAssetCollection, withURL url: URL, onSaveSuccess:PHSaveSuccessHandler?, onError:ErrorHandler?) {
        
        var assetPlaceHolder:PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            
            let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            assetPlaceHolder = assetRequest?.placeholderForCreatedAsset
            
            guard(assetPlaceHolder != nil) else {
                print("no assetPlaceholder when saving video")
                onError?(NSError())
                return
            }
            
            if let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection) {
                albumChangeRequest.addAssets([assetPlaceHolder!] as NSArray)
            } else {
                print("album change request object unexpectedly nil")
                onError?(NSError())
                return
            }
            
        }) { (success, error) in
            if success {
                print("movie added to album, SUCCESS!")
                let assets:PHFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetPlaceHolder!.localIdentifier], options: nil)
                if let asset = assets.firstObject {
                    onSaveSuccess?(asset)
                    return
                }
            }
            
            let error = error ?? NSError()
            onError?(error)
            return
        }
    }
    
    private static func getLocalPath(path:String?) -> String {
        if let path = path {
            return path
        } else {
            return NSHomeDirectory() + "/tmp/nwimagesequence.mov"
        }
    }
    
}
