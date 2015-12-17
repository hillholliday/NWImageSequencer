## Synopsis

`NWImageSequencer` is a quick and easy to use Swift 2.0 framework for generating movie files from an array of images.


## Code Example

**Basic Usage**

You must first instantiate an instance of NWImageSequencer

```
let sequencer = NWImageSequencer()
```


The following steps create a movie in your local directory using **Closures**
 
```
let images:[UIImage] //<--your array of images
let options = NWImageSequencerOptions(outputSize: CGSize(720,720), secondsPerImage: 2.5)

sequencer.createLocalMovieWithImages(images, options: options,
            onSuccess: { (movieUrl) -> Void in
                print("movie successfully created at \(movieUrl)")
            }, 
            onError: { (error) -> Void in
                print("error occured creating movie \(error)")
            }, 
            onProgress: { (progress) -> Void in
                print("progress creating movie reported at \(progress)")
            })
```

NWImageSequencer also has helper functions to save the movie created in the local directory to an album the photo roll using the Photos framework. The success block returns a PHAsset instance that can be used to fetch the saved video

```
self.sequencer?.saveMovieAtUrl(movieUrl, toAlbumNamed: "Example", 
                               onSaveSuccess: { (asset) -> Void in
                                    print("Sucessfully saved video asset: \(asset)")
                               }, 
                               onError: { (error) -> Void in
                                    print("Error saving video: \(error)")
                               })
``` 

If you prefer to use **delegation**, there are alternate methods that accept classes confroming to  `NWImageSequencerDelegate` and `NWImageSequencerSaveDelegate` protocols

**Configuration**

the `NWImageSequencerOptions` object is where you configure the options for the generated movie.

```
let options =  NWImageSequencerOptions(
	   outputSize:CGSize //width and height of exported movie (required)
	   secondsPerImage:Float //time in seconds each image is displayed (default = 1)
	   localPath:String //specify local path in app directory to save movie (optional)
	   fileType:String //file format of generated movie (default = AVFileTypeQuickTimeMovie)
)
```

##Tips
* When passing in images of various sizes, `NWImageSequencer` always fits the movie to the largest width and height found in the images array. *For best results you will probably want to stick with images of the same size and ensure that the outputSize always matches the aspect ratio of the source images.*

* Generating larger size movies can cause some ios devices to crash.

* Generating exceptionally long movies has not been tested

* FileFormats other than the default `AVFileTypeQuickTimeMovie` have not been tested


##TODO

* Add better image fitting options to handle images of various sizes
* Add ability to specify display time for each image individually
* Add ability to set background color
* Add objective-C examples






