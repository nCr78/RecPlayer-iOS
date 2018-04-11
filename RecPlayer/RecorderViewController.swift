//
//  RecorderViewController.swift
//  Recorder
//
//  Created by Eleftherios Krm on 31/3/18.
//  Copyright © 2018 Eleftherios Krm. All rights reserved.
//

import UIKit
import AVFoundation
import AudioKit
import AudioKitUI

class RecorderViewController: UIViewController{
    
    @IBOutlet weak var inputPlot: UIView!
    @IBOutlet weak var outputView: UIView!
    @IBOutlet weak var verticalLine: UIView!
    
    @IBOutlet weak var viewAroundPlayBtn: UIView!
    @IBOutlet weak var viewAroundMainBtn: UIView!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var mainButton: UIButton!
    
    @IBOutlet var statusLabel: UILabel!
    
    var playBtnOrigin: CGFloat!
    
    var meterTimer: Timer!
    var soundFileURL: URL!
    
    var recorder: AVAudioRecorder!
    var player = AKPlayer()
    
    var myRecorder : RecordAudio? = nil
    var mySpectrumView : SpectrumView?
    var displayLink : CADisplayLink!
    var outputPlot: EZAudioPlot!
    
    var originX: CGFloat?
    var waveformWidth: CGFloat!
    var outputViewWidth: CGFloat!
    var currentPosition = Double(0)
    var animating = false
    var shouldStop = false
    
    enum recordState {
        case readyToRecord
        case recording
    }
    
    enum playState {
        case readyToPlay
        case playing
    }
    
    var recordingState = recordState.readyToRecord{
        didSet{
            switch recordingState {
            case .readyToRecord:
                viewAroundPlayBtn.isUserInteractionEnabled = true
                playButton.isEnabled = true
                playButton.setImage(#imageLiteral(resourceName: "playButtonBlack128"), for: .normal)
                animateRadius(mainButton.layer, radius: mainButton.frame.width/2)
            case .recording:
                navigationItem.rightBarButtonItem?.isEnabled = false
                viewAroundPlayBtn.isUserInteractionEnabled = false
                playButton.isEnabled = false
                playButton.setImage(#imageLiteral(resourceName: "playButtonBlack128"), for: .normal)
                animateRadius(mainButton.layer, radius: mainButton.frame.width/4)
            }
        }
    }
    
    var playingState = playState.readyToPlay {
        didSet{
            switch playingState {
            case .readyToPlay:
                playButton.setImage(#imageLiteral(resourceName: "playButtonBlack128"), for: .normal)
                playButton.frame.origin.x = playBtnOrigin
                viewAroundMainBtn.isUserInteractionEnabled = true
                mainButton.isEnabled = true
                mainButton.backgroundColor = UIColor.red
            case .playing:
                playButton.setImage(#imageLiteral(resourceName: "pauseButtonBlack128"), for: .normal)
                playButton.frame.origin.x = playBtnOrigin + 2
                viewAroundMainBtn.isUserInteractionEnabled = false
                mainButton.isEnabled = false
                mainButton.backgroundColor = UIColor.lightGray
            }
        }
    }
    
    @objc func updateViews() {
        guard (myRecorder != nil) else { return }
        if myRecorder!.isRecording {
            mySpectrumView?.makeSpectrumFromAudio(myRecorder!)
            mySpectrumView?.setNeedsDisplay()
        }
        
        if !animating && player.isPlaying && !shouldStop {
            if let song = player.audioFile, song.duration > 0 {
                let division = CGFloat((player.currentTime ) / song.duration)
                let progress = -waveformWidth * division
                
                let nextDivision = CGFloat((player.currentTime + 2*((displayLink?.duration)!)) / song.duration)
                if nextDivision >= 1 {
                    shouldStop = true
                    playingEnded()
                }
                else {outputPlot.frame.origin.x = progress + outputViewWidth/2}
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if let r = myRecorder {if r.isRecording == true {r.stopRecording()}}
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let r = myRecorder {if r.isRecording == false {r.startRecording()}}
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.setupAnim()
        self.askForNotifications()
        self.checkHeadphones()
        self.setupRecorder()
        self.setupAudioKit()
    }
    
    func resetAudio()
    {
        NotificationCenter.default.removeObserver(self)
        displayLink.invalidate()
        if meterTimer != nil {
            if meterTimer.isValid {meterTimer.invalidate()}
        }
        
        if recorder != nil {recorder.stop()}
        player.stop()
        if myRecorder != nil {myRecorder?.stopRecording()}

        globalAudioRecorder = nil
    }
    
    @objc func userDidSelectCancel(_ sender: AnyObject!) {
        resetAudio()
        navigationController?.popViewController(animated: true)
    }
    
    @objc func userDidSelectSave(_ sender: AnyObject!) {
        print("Save tapped.")
//        verticalLine.removeFromSuperview()
//
//        let layerImage = UIImage(view: outputView)
//
//        let imageRef: CGImage = layerImage.cgImage!.cropping(to: CGRect(x: (UIScreen.main.scale * outputPlot.frame.origin.x), y: (UIScreen.main.scale * outputPlot.frame.origin.y), width: (UIScreen.main.scale * 115.0), height: (UIScreen.main.scale * outputPlot.bounds.height)))!
//        let img = UIImage(cgImage: imageRef)
//
//        let avAudioFile = player.audioFile
//
//        shared.attachmentsController?.addAudio(thumbnail: img, url: (avAudioFile?.url)!)
        resetAudio()
        navigationController?.popViewController(animated: true)
    }
    
    func setupUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(self.userDidSelectSave(_:)))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(self.userDidSelectCancel(_:)))
        
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        outputViewWidth = outputView.frame.width
        viewAroundMainBtn.layer.cornerRadius = viewAroundMainBtn.frame.width / 2
        viewAroundMainBtn.layer.borderWidth = 2.0
        viewAroundMainBtn.layer.borderColor = UIColor.black.cgColor
        viewAroundMainBtn.backgroundColor = UIColor.clear
        
        viewAroundPlayBtn.layer.cornerRadius = viewAroundMainBtn.frame.width / 2
        viewAroundPlayBtn.layer.borderWidth = 2.0
        viewAroundPlayBtn.layer.borderColor = UIColor.black.cgColor
        viewAroundPlayBtn.backgroundColor = UIColor.clear
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(self.mainBtn))
        viewAroundMainBtn.addGestureRecognizer(gesture)
        
        let gesture2 = UITapGestureRecognizer(target: self, action: #selector(self.playBtn))
        viewAroundPlayBtn.addGestureRecognizer(gesture2)
        
        mainButton.layer.cornerRadius = mainButton.frame.width / 2
        
        mainButton.sendSubview(toBack: viewAroundMainBtn)
        playButton.sendSubview(toBack: viewAroundPlayBtn)
        playBtnOrigin = playButton.frame.origin.x
        
        verticalLine.layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.draggedView(_:)))
        outputView.isUserInteractionEnabled = true
        outputView.addGestureRecognizer(panGesture)
    }
    
    func setupAudioKit() {
        AKSettings.defaultToSpeaker = true
        AKSettings.playbackWhileMuted = true
        AudioKit.output = player
        if !audioKitStarted{
            do {try AudioKit.start();audioKitStarted = true}
            catch {AKLog("AudioKit did not start!\(error)")}
        }
        
        self.setSessionPlayAndRecord()
    }
    
    func setupAnim() {
        myRecorder = RecordAudio()
        myRecorder!.startRecording()
        globalAudioRecorder = myRecorder
        
        let r2 = inputPlot.bounds
        mySpectrumView = SpectrumView()
        mySpectrumView!.frame = r2
        inputPlot.addSubview(mySpectrumView!)
        
        displayLink = CADisplayLink(target: self, selector: #selector(self.updateViews))
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: RunLoop.current, forMode: RunLoopMode.commonModes )
    }
    
    func setupStaticPlot() {
        if outputPlot != nil {if outputPlot.isDescendant(of: outputView) {outputPlot.removeFromSuperview()}}
        
        let newfile = EZAudioFile(url: player.audioFile?.url)
        let size = Int(30 * (player.audioFile?.duration)!)
        
        guard let data = newfile?.getWaveformData(withNumberOfPoints: UInt32(size)) else { return }
        outputPlot = EZAudioPlot()
        
        outputPlot.frame = CGRect(x: Int(outputView.bounds.origin.x + outputViewWidth/2), y: Int(outputView.bounds.origin.x), width: size, height: Int(outputView.bounds.height))
        outputPlot.plotType = EZPlotType.buffer
        outputPlot.shouldFill = true
        outputPlot.shouldMirror = true
        outputPlot.color = .black
        outputPlot.updateBuffer( data.buffers[0], withBufferSize: data.bufferSize )
        
        outputView.addSubview(outputPlot)
        originX = outputPlot.center.x
        waveformWidth = outputPlot.bounds.width
    }
    
    @objc func draggedView(_ sender:UIPanGestureRecognizer){
        if player.audioFile == nil{return}
        animating = true
        view.bringSubview(toFront: outputPlot)
        
        let translation = sender.translation(in: view)
        let newX = outputPlot.center.x + (1.2*translation.x)
        
        if newX <= originX! && (newX >= -waveformWidth/2 + outputViewWidth/2) {
            outputPlot.center.x = newX
        }
        else if newX >= originX! {
            outputPlot.center.x = originX!
        }
        else if (newX <= -waveformWidth/2 + outputViewWidth/2) {
            outputPlot.center.x = -waveformWidth/2 + outputViewWidth/2
        }
        
        sender.setTranslation(CGPoint.zero, in: self.view)
        if sender.state == .cancelled || sender.state == .ended {
            let point = -Double((outputPlot.frame.origin.x - outputViewWidth/2) / waveformWidth)
            print(point)
            if point >= 1.0 {playingEnded()}
            else{player.setPosition((player.audioFile?.duration)! * point)}
            
            currentPosition = player.currentTime
            animating = false
        }
    }
    
    @objc func updateAudioMeter(_ timer: Timer) {
        if let recorder = self.recorder {
            if recorder.isRecording {
                let min = Int(recorder.currentTime / 60)
                let sec = Int(recorder.currentTime.truncatingRemainder(dividingBy: 60))
                let s = String(format: "%02d:%02d", min, sec)
                statusLabel.text = s
                recorder.updateMeters()
                //other possible graphics...
                //var apc0 = recorder.averagePowerForChannel(0)
                //var peak0 = recorder.peakPowerForChannel(0)
            }
        }
    }
    
    func animateRadius(_ layer: CALayer, radius: CGFloat){
        UIViewPropertyAnimator(duration: 0.15, curve: .easeIn) {layer.cornerRadius = radius}.startAnimation()
    }
    
    override func didReceiveMemoryWarning(){
        super.didReceiveMemoryWarning()
        recorder = nil
    }
    
    @IBAction func removeAll(_ sender: AnyObject) {deleteAllRecordings()}
    
    @objc func playBtn() {
        switch playingState {
        case .readyToPlay:
            play()
        case .playing:
            stopPlaying()
        }
    }
    
    @objc func mainBtn() {
        switch recordingState {
        case .readyToRecord:
            record()
        case .recording:
            stopRecording()
        }
    }
    
    func record() {
        recordingState = .recording
        recorder.record()
        
        meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                          target: self,
                                          selector: #selector(self.updateAudioMeter(_:)),
                                          userInfo: nil,
                                          repeats: true)
    }
    
    func stopPlaying() {
        if playingState == .playing
        {
            currentPosition = player.currentTime
            player.stop()
            let division = ((currentPosition ) / (player.audioFile?.duration)!)
            print(division)
            if division >= 0.998
            {
                shouldStop = true
                player.setPosition(0.0)
                currentPosition = 0.0
            }
        }
        playingState = .readyToPlay
    }
    
    func stopRecording()
    {
        if recordingState == .recording
        {
            recorder?.stop()
            currentPosition = 0
            if outputPlot != nil {outputPlot.clear()}
            var url: URL?
            if self.recorder != nil {url = self.recorder.url}
            else {url = self.soundFileURL!}
            do {
                try player.load(url: url!)
                player.completionHandler = playingEnded
                player.prepare()
                player.volume = 1.0
            }
            catch
            {
                print("error loading url file")
            }
            setupStaticPlot()
        }
        recordingState = .readyToRecord
        if meterTimer != nil{meterTimer.invalidate()}
        
        //recorder = nil
    }
    
    func play() {
        playingState = .playing
        
        player.play(from: currentPosition)
        shouldStop = false
    }
    
    func playingEnded()
    {
        currentPosition = (player.audioFile?.duration)!
        player.stop()
        player.setPosition(currentPosition)
        DispatchQueue.main.async {
            print("playing ended")
            self.stopPlaying()
        }
    }
    
    func setupRecorder() {
        
        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
        let currentFileName = "recording-\(format.string(from: Date())).m4a"
        //        print(currentFileName)
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.soundFileURL = documentsDirectory.appendingPathComponent(currentFileName)
        //        print("writing to soundfile url: '\(soundFileURL!)'")
        
        if FileManager.default.fileExists(atPath: soundFileURL.absoluteString) {
            // probably won't happen. want to do something about it?
            print("soundfile \(soundFileURL.absoluteString) exists")
        }
        
        let recordSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey: 32000,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0
        ]
        
        do {
            recorder = try AVAudioRecorder(url: soundFileURL, settings: recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
        } catch {
            recorder = nil
            print(error.localizedDescription)
        }
    }
    
    func setSessionPlayAndRecord() {
        let session = AVAudioSession.sharedInstance()
        do {try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)}
        catch {
            print("could not set session category")
            print(error.localizedDescription)
        }
        
        do{try session.setMode(AVAudioSessionModeDefault)}
        catch{
            print("could not set mode")
            print(error.localizedDescription)
        }
        
        do {try session.setActive(true)}
        catch {
            print("could not make session active")
            print(error.localizedDescription)
        }
    }
    
    func deleteAllRecordings() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory,
                                                            includingPropertiesForKeys: nil,
                                                            options: .skipsHiddenFiles)
            //                let files = try fileManager.contentsOfDirectory(at: documentsDirectory)
            var recordings = files.filter({ (name: URL) -> Bool in
                return name.pathExtension == "m4a"
                //                    return name.hasSuffix("m4a")
            })
            for i in 0 ..< recordings.count {
                //                    let path = documentsDirectory.appendPathComponent(recordings[i], inDirectory: true)
                //                    let path = docsDir + "/" + recordings[i]
                
                //                    print("removing \(path)")
                print("removing \(recordings[i])")
                do {try fileManager.removeItem(at: recordings[i])}
                catch {
                    print("could not remove \(recordings[i])")
                    print(error.localizedDescription)
                }
            }
        }
        catch {
            print("could not get contents of directory at \(documentsDirectory)")
            print(error.localizedDescription)
        }
    }
    
    func askForNotifications() {
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(RecorderViewController.background(_:)),
                                               name: NSNotification.Name.UIApplicationWillResignActive,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(RecorderViewController.foreground(_:)),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(RecorderViewController.routeChange(_:)),
                                               name: NSNotification.Name.AVAudioSessionRouteChange,
                                               object: nil)
    }
    
    @objc func background(_ notification: Notification) {
        print("\(#function)")
        if let r = myRecorder {if r.isRecording == true {r.stopRecording()}}
    }
    
    @objc func foreground(_ notification: Notification) {
        print("\(#function)")
        if let r = myRecorder {if r.isRecording == false {r.startAudioUnit()}}
    }
    
    @objc func routeChange(_ notification: Notification) {
        if let userInfo = (notification as NSNotification).userInfo {
            //            print("routeChange \(userInfo)")
            
            //print("userInfo \(userInfo)")
            if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt {
                //print("reason \(reason)")
                switch AVAudioSessionRouteChangeReason(rawValue: reason)! {
                case AVAudioSessionRouteChangeReason.newDeviceAvailable:
                    print("NewDeviceAvailable")
                    print("did you plug in headphones?")
                    checkHeadphones()
                case AVAudioSessionRouteChangeReason.oldDeviceUnavailable:
                    print("OldDeviceUnavailable")
                    print("did you unplug headphones?")
                    checkHeadphones()
                case AVAudioSessionRouteChangeReason.categoryChange:
                    print("CategoryChange")
                case AVAudioSessionRouteChangeReason.override:
                    print("Override")
                case AVAudioSessionRouteChangeReason.wakeFromSleep:
                    print("WakeFromSleep")
                case AVAudioSessionRouteChangeReason.unknown:
                    print("Unknown")
                case AVAudioSessionRouteChangeReason.noSuitableRouteForCategory:
                    print("NoSuitableRouteForCategory")
                case AVAudioSessionRouteChangeReason.routeConfigurationChange:
                    print("RouteConfigurationChange")
                }
            }
        }
    }
    
    func checkHeadphones() {
        // check NewDeviceAvailable and OldDeviceUnavailable for them being plugged in/unplugged
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        if !currentRoute.outputs.isEmpty {
            for description in currentRoute.outputs {
                if description.portType == AVAudioSessionPortHeadphones {
                    print("headphones are plugged in")
                    break
                }
                else {print("headphones are unplugged")}
            }
        }
        else {print("checking headphones requires a connection to a device")}
    }
}

// MARK: AVAudioRecorderDelegate
extension RecorderViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("finished recording \(flag)")
        navigationItem.rightBarButtonItem?.isEnabled = true
        //        self.recorder = nil
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let e = error {print("\(e.localizedDescription)")}
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
}
