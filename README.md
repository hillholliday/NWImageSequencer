## Synopsis

If you hate working with AVAssetWriters and AVAssetWriterInputs and AVAssetWriterInputPixelBufferAdapters as much as I do, and all you want to do is create a damn movie file from a collection of images without writing 300 lines of code then maybe you won't hate using `NWImageSequencer` - a small Swift (4.0) framework which lets you do exactly that in only a few lines of code.

## Code Example

**Basic Usage**

The following steps create a movie in your local directory.
 
```
let images:[UIImage] //<--your array of images
let options = NWImageSequencerOptions(outputSize: CGSize(720,720), secondsPerImage: 2.5)

NWImageSequencer.createLocalMovieWithImages(images, options: options,
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
NWImageSequencer.saveMovieAtUrl(movieUrl, toAlbumNamed: "Example", 
                               onSaveSuccess: { (asset) -> Void in
                                    print("Sucessfully saved video asset: \(asset)")
                               }, 
                               onError: { (error) -> Void in
                                    print("Error saving video: \(error)")
                               })
``` 

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






