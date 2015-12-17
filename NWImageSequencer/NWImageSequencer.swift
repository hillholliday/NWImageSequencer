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
public typealias SuccessHandler = (movieUrl: NSURL) -> Void
public typealias ErrorHandler = (error: NSError) -> Void
public typealias ProgressHandler = (progress:Float) ->Void
public typealias PHSaveSuccessHandler = (asset: PHAsset) -> Void

//MARK: Private

private let NWImageSequencerErrorDomain = "NWImageSequencerErrorDomain"

private enum ErrorCodes: Int {
    case Unkown = 0
    case UncompatibleFormat = 1
    case NullBufferError = 2
    case NullContextError = 3
    case NullColorSpaceError = 4
    case LocalPathError = 5
}

private enum PixelBufferError: ErrorType {
    case NullBufferError
    case NullContextError
    case NullColorSpaceError
}

private enum PathError: ErrorType {
    case NullPathError
}

public protocol NWImageSequencerDelegate: class {
    func imageSequencer(imageSequencer:NWImageSequencer, didCreateMovieAtURL url:NSURL)
    func imageSequencer(imageSequencer:NWImageSequencer, failedToCreateMovieWithError error:NSError)
    func imageSequencer(imageSequencer:NWImageSequencer, sequenceCreationDidReportProgress progress:Float)
}

public protocol NWImageSequencerSaveDelegate: class {
    func imageSequencer(imageSequencer:NWImageSequencer, didSaveMovieToAlbumWithAsset asset:PHAsset)
    func imageSequencer(imageSequencer:NWImageSequencer, failedToSaveMovieToCameraRollWithError error:NSError)
}

//MARK: - NWImageSequencer
public class NWImageSequencer {
    
    //MARK: Private Instance Properties
    weak private var delegate:NWImageSequencerDelegate?
    weak private var saveDelegate:NWImageSequencerSaveDelegate?
    
    //MARK: Private Static Methods
    private static func getErrorForCode(code:ErrorCodes) -> NSError {
        var userInfo = [NSObject : AnyObject]()
        var description:String = "An Unknown error occured"
        var failureReason:String = "Reason for failure is unknown"
        let recoverySuggestion:String = "Unknown recovery suggestion"
        
        switch code {
        case .Unkown:
            description = "Error occured for an unknown reason"
        case .NullBufferError:
            description = "A null buffer error was encountered"
            failureReason = "The buffer was null or could not be created"
        case .NullColorSpaceError :
            description  = "Missing color space encountered"
            failureReason = "Color space could not be created for device rbg"
        case .NullContextError:
            description = "Missing context encountered when drawing frame"
            failureReason = "Context was null"
        case .UncompatibleFormat:
            description = "Unable to save video to photo album"
            failureReason = "Video file format is not compatable with photo album"
        case .LocalPathError:
            description = "Unable to write temporary video to local path"
            failureReason = "Local path could not be opened"
        }
        
        userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(description, comment: "")
        userInfo[NSLocalizedFailureReasonErrorKey] = NSLocalizedString(failureReason , comment: "")
        userInfo[NSLocalizedRecoverySuggestionErrorKey] = NSLocalizedString(recoverySuggestion , comment: "")
        
        
        return NSError(domain: NWImageSequencerErrorDomain, code: code.rawValue, userInfo: userInfo)
    }
    
    private static func pixelBufferFromCGImage(cgImage:CGImageRef, withSourceSize size:CGSize) throws -> CVPixelBufferRef {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let options:[NSObject : AnyObject] = [
            kCVPixelBufferCGImageCompatibilityKey : true,
            kCVPixelBufferCGBitmapContextCompatibilityKey : true
        ]
        var pxBuffer:CVPixelBufferRef? = nil
        
        let status:CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options, &pxBuffer)
        
        guard let buffer = pxBuffer where status == kCVReturnSuccess else {
            throw PixelBufferError.NullBufferError
        }
        
        CVPixelBufferLockBaseAddress(buffer,0)
        let pxData = CVPixelBufferGetBaseAddress(buffer)
        
        guard let rbgColorSpace = CGColorSpaceCreateDeviceRGB() else {
            throw PixelBufferError.NullColorSpaceError
        }
        
        guard let context = CGBitmapContextCreate(pxData,width,height,8,4*width,rbgColorSpace,CGImageAlphaInfo.NoneSkipFirst.rawValue) else {
            throw PixelBufferError.NullContextError
        }
        
        CGContextConcatCTM(context, CGAffineTransformMakeRotation(0))
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(CGImageGetWidth(cgImage)),CGFloat(CGImageGetHeight(cgImage))), cgImage);
        CVPixelBufferUnlockBaseAddress(buffer, 0)
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

    
    //MARK: Public Methods
    
    public init() {
        
    }
    
    public func createLocalMovieWithImages(images:[UIImage], options: NWImageSequencerOptions, delegate: NWImageSequencerDelegate) {
        self.delegate = delegate
        createLocalMovieWithImages(images, options: options, onSuccess: nil, onError: nil, onProgress: nil)
    
    }
    
    public func createLocalMovieWithImages(images:[UIImage], options: NWImageSequencerOptions, onSuccess:SuccessHandler?, onError: ErrorHandler?, onProgress: ProgressHandler?) {
        
        let path:String
        
        do {
            path = try getLocalPath(options.localPath)
            let tempURL = NSURL.fileURLWithPath(path)
            let manager = NSFileManager.defaultManager()
            do {
              try manager.removeItemAtPath(tempURL.path!)
            } catch {
               //ignore
            }
        } catch PathError.NullPathError{
            onError?(error: NWImageSequencer.getErrorForCode(.LocalPathError))
            return
        } catch {
            onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
            return
        }
        
        //now we have a path
        let url = NSURL(fileURLWithPath: path)
        let movieWriter:AVAssetWriter
        do {
            movieWriter = try AVAssetWriter.init(URL:url, fileType: options.fileType)
        } catch let error as NSError {
            delegate?.imageSequencer(self, failedToCreateMovieWithError: error)
            return
        }
        
        let sourceSize = NWImageSequencer.getLargestSizeToContainImages(images)
        let outputSettings:[String:AnyObject] = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : Int(options.outputSize.width),
            AVVideoHeightKey : Int(options.outputSize.height)
        ]
        
        let movieWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: movieWriterInput, sourcePixelBufferAttributes: nil)
        
        movieWriter.addInput(movieWriterInput)
        movieWriter.startWriting()
        movieWriter.startSessionAtSourceTime(kCMTimeZero)
        
        var buffer:CVPixelBufferRef? = nil
        
        var i = 0
        let ticSize:Int64 = Int64(round( 600 / options.secondsPerImage))
        
        while(true) {
            if(movieWriterInput.readyForMoreMediaData) {
                let frameTime = CMTimeMake(ticSize, 600)
                let lastTime = CMTimeMake(Int64(i)*ticSize, 600)
                var presentTime = CMTimeAdd(lastTime, frameTime)
                if(i == 0) {
                    presentTime = CMTimeMake(0,600)
                }
                
                if (i >= images.count) {
                    buffer = nil
                } else {
                    do {
                        //grab the next image
                        try buffer = NWImageSequencer.pixelBufferFromCGImage(images[i].CGImage!, withSourceSize: sourceSize)
                    } catch PixelBufferError.NullBufferError {
                        onError?(error: NWImageSequencer.getErrorForCode(.NullBufferError))
                        delegate?.imageSequencer(self, failedToCreateMovieWithError: NWImageSequencer.getErrorForCode(.NullBufferError))
                        return
                    } catch PixelBufferError.NullColorSpaceError {
                        onError?(error: NWImageSequencer.getErrorForCode(.NullColorSpaceError))
                        delegate?.imageSequencer(self, failedToCreateMovieWithError: NWImageSequencer.getErrorForCode(.NullColorSpaceError))
                        return
                    } catch PixelBufferError.NullContextError {
                        onError?(error: NWImageSequencer.getErrorForCode(.NullContextError))
                        delegate?.imageSequencer(self, failedToCreateMovieWithError: NWImageSequencer.getErrorForCode(.NullContextError))
                        return
                    } catch {
                        
                    }
                }
                
                if let buffer = buffer {
                    pixelBufferAdaptor.appendPixelBuffer(buffer, withPresentationTime: presentTime)
                    i++
                    let prog = Float(i)/Float(images.count)
                    delegate?.imageSequencer(self, sequenceCreationDidReportProgress: prog)
                    onProgress?(progress:prog)
                } else {
                    movieWriterInput.markAsFinished()
                    movieWriter.finishWritingWithCompletionHandler({ () -> Void in
                        //if(movieWriter.status != AVAssetWriterStatus.Failed && movieWriter.status == AVAssetWriterStatus.Completed) {
                        if(movieWriter.status == AVAssetWriterStatus.Completed) {
                            let tempURL = NSURL.fileURLWithPath(path)
                            self.delegate?.imageSequencer(self, didCreateMovieAtURL: tempURL)
                            onSuccess?(movieUrl: tempURL)
                        } else {
                            if let error = movieWriter.error {
                                self.delegate?.imageSequencer(self, failedToCreateMovieWithError:error)
                                onError?(error: error)
                            } else {
                                self.delegate?.imageSequencer(self, failedToCreateMovieWithError: NWImageSequencer.getErrorForCode(.Unkown))
                                onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                            }
                        }
                    })
                    break;
                }
            }
        }
    }
    
    
    public func saveMovieAtUrl(url:NSURL, toAlbumNamed albumName:String, onSaveSuccess:PHSaveSuccessHandler?, onError:ErrorHandler?) {
        
        //try to fetch the named album
        let fetchOptions = PHFetchOptions()
        var placeHolder:PHObjectPlaceholder? = nil
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollectionsWithType(PHAssetCollectionType.Album, subtype: PHAssetCollectionSubtype.Any, options: fetchOptions).firstObject
        
        //if it doesn't exist, create it.
        if collection == nil {
            print("collection did not exist")
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                  let createAlbum = PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(albumName)
                  placeHolder = createAlbum.placeholderForCreatedAssetCollection
                }, completionHandler: { (success, error) -> Void in
                    if success == true && placeHolder != nil {
                        let collectionFetchResult = PHAssetCollection.fetchAssetCollectionsWithLocalIdentifiers([placeHolder!.localIdentifier], options: nil)
                        if let assetCollection:PHAssetCollection = collectionFetchResult.firstObject as? PHAssetCollection {
                            self.saveMovieToCollection(assetCollection, withURL: url, onSaveSuccess:onSaveSuccess, onError:onError )
                            return
                        } else {
                            print("failed to save movie to camera roll as assetCollection was nil")
                            self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: NWImageSequencer.getErrorForCode(.Unkown))
                            onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                            return
                        }
                        
                    } else if let error = error {
                        print("unable to create asset collection due to error \(error)")
                        self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: error)
                        onError?(error: error)
                        return
                    } else {
                        print("unable to create asset collection, not sure why happened here")
                        self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: NWImageSequencer.getErrorForCode(.Unkown))
                        onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                        return
                    }
            })
        } else {
            self.saveMovieToCollection(collection! as! PHAssetCollection, withURL: url, onSaveSuccess:onSaveSuccess, onError:onError )
        }
        
    }
    
    
    //MARK: Private Methods
    
    private func saveMovieToCollection(collection:PHAssetCollection, withURL url:NSURL, onSaveSuccess:PHSaveSuccessHandler?, onError:ErrorHandler? ) {
        //save the movie to that collection
        var assetPlaceHolder:PHObjectPlaceholder?
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(url)
            assetPlaceHolder = assetRequest?.placeholderForCreatedAsset
            
            guard (assetPlaceHolder != nil) else {
                print("no assetPlaceholder when saving video")
                self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: NWImageSequencer.getErrorForCode(.Unkown))
                onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                return
            }
            
            if let albumChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: collection){
                albumChangeRequest.addAssets([assetPlaceHolder!])
                print("albumChangeRequest \(albumChangeRequest)")
            } else {
                print("album change request object unexpectedly nil")
                self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: NWImageSequencer.getErrorForCode(.Unkown))
                onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                return
            }
            
            }) { (success, error) -> Void in
                if success {
                    print("movie added to album, SUCCESS!")
                    //TODO: how to we get the url?
                    print("assetPlaceholder is \(assetPlaceHolder!)")
                    let assets:PHFetchResult = PHAsset.fetchAssetsWithLocalIdentifiers([assetPlaceHolder!.localIdentifier], options: nil)
                    if let asset = assets.firstObject as? PHAsset {
                        self.saveDelegate?.imageSequencer(self, didSaveMovieToAlbumWithAsset: asset)
                        onSaveSuccess?(asset: asset)
                    } else {
                        self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: NWImageSequencer.getErrorForCode(.Unkown))
                        onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                    }
                    
                } else if let error = error {
                    print("movie save error \(error)")
                    self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: error)
                    onError?(error:error)
                } else {
                    self.saveDelegate?.imageSequencer(self, failedToSaveMovieToCameraRollWithError: NWImageSequencer.getErrorForCode(.Unkown))
                    onError?(error: NWImageSequencer.getErrorForCode(.Unkown))
                }
        }

    }
    
    private func getLocalPath(path:String?) throws -> String {
        if let path = path {
            return path
        } else if let path = (NSString(UTF8String: NSHomeDirectory())?.stringByAppendingPathComponent("tmp/nwimagesequence.mov")) {
            return path
        } else {
            throw PathError.NullPathError
        }
    }
    
    }