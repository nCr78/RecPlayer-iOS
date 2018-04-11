# RecPlayer-iOS
A simple iOS application that records audio and plays it back. (+some animations)

This project was made to test a specific behaviour of AudioKit's AKMicrophone. The main project uses a custom AVFoundation microphone instead of AKMicrophone. It does use AudioKit for the second audio plot you see in the demo.png though. 

You can find the AudioKit version of the same implementation (record & play) inside the "TheAudioKitVersionHere/recorder_" folder. You can compare their behaviours. (Mainly the red recording bar that remains in AudioKit version when the app is running in the background).

<p >
  <img src="https://github.com/nCr78/RecPlayer-iOS/blob/master/demo.png" width="278"/>
</p>
