//
//  ImageCollectionViewController.swift
//  hhmoviemaker
//
//  Created by Nat Wales on 12/7/15.
//  Copyright © 2015 Hill Holliday. All rights reserved.
//

import UIKit
import NWImageSequencer
import Photos

class ImageCollectionViewController: UICollectionViewController, NWImageSequencerDelegate {

    private var sequencer:NWImageSequencer?
    private var images = [UIImage]()
    private var path:String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImages()
        setupMovieMaker()
        // Register cell classes
        collectionView?.reloadData()
    }

    private func setupImages() {
        images.removeAll()
        images.append(UIImage(named: "one.jpg")!)
        images.append(UIImage(named: "two.jpg")!)
        images.append(UIImage(named: "three.jpg")!)
        images.append(UIImage(named: "four.jpg")!)
        images.append(UIImage(named: "five.jpg")!)
        images.append(UIImage(named: "six.jpg")!)
        images.append(UIImage(named: "seven.jpg")!)
        images.append(UIImage(named: "eight.jpg")!)
        images.append(UIImage(named: "nine.jpg")!)
    }
    
    private func setupMovieMaker() {
        sequencer = NWImageSequencer()
        self.navigationItem.title = "Demo"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Make It", style:UIBarButtonItemStyle.Done, target: self, action: "makeMovie")
       
    }
    
    func makeMovie() {
        //Note: if output size is too big it will fail to save on some ios devices
        let options = NWImageSequencerOptions(outputSize: CGSizeMake(720,720), secondsPerImage: 2.5)
        sequencer?.createLocalMovieWithImages(images, options: options,
            onSuccess: { (movieUrl) -> Void in
                print("success, movie created at \(movieUrl)")
                self.sequencer?.saveMovieAtUrl(movieUrl, toAlbumNamed: "Example", onSaveSuccess: { (asset) -> Void in
                    print("Saved video. Returned asset is: \(asset)")
                    }, onError: { (error) -> Void in
                        print("Error saving video: \(error)")
                })
            }, onError: { (error) -> Void in
                print("error occured creating movie \(error)")
            }, onProgress: { (progress) -> Void in
                print("progress creating movie reported at \(progress)")
        })
        
        //show progress
    }
    
    
    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCellWithReuseIdentifier("imageCell", forIndexPath: indexPath) as? ImageCollectionViewCell {
            cell.backgroundColor = UIColor.redColor()
            cell.imageView.image = self.images[indexPath.row]
            return cell
        }
        
        // Configure the cell
        return UICollectionViewCell()
    }

    // MARK: NWImageSequencer Delegate
    
    func imageSequencer(imageSequencer:NWImageSequencer, didCreateMovieAtURL url:NSURL) {
        print("did create Movie at URL \(url)")
    }
    
    func imageSequencer(imageSequencer:NWImageSequencer, didSaveMovieToCameraRollURL url:NSURL) {
        print("did save movie to camera roll at url \(url)")
    }
    
    func imageSequencer(imageSequencer:NWImageSequencer, failedToCreateMovieWithError error:NSError){
        print("failed to create movie with error \(error)")
    }
    
    func imageSequencer(imageSequencer:NWImageSequencer, failedToSaveMovieToCameraRollWithError error:NSError){
        print("failed to save movie to camera roll with error \(error)")
    }
    
    func imageSequencer(imageSequencer: NWImageSequencer, sequenceCreationDidReportProgress progress: Float) {
        print("progress reported as \(progress)")
    }
}
