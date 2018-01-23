//
//  ImageSequencerOptions.swift
//
//  Created by Nat on 12/9/15.
//

import Foundation
import UIKit
import AVFoundation

public struct NWImageSequencerOptions {
    
    let secondsPerImage:Float
    let outputSize:CGSize
    let fileType:AVFileType
    let localPath:String?
    
    public init(outputSize:CGSize, secondsPerImage:Float = 1.0, localPath:String? = nil, fileType:AVFileType = AVFileType.mov) {
        self.secondsPerImage = secondsPerImage
        self.outputSize = outputSize
        self.localPath = localPath
        self.fileType = fileType
    }
}
