//
//  AppDelegate.swift
//  Recorder
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2017 AudioKit. All rights reserved.
//

import AudioKit
import AudioKitUI
import UIKit

class ViewController: UIViewController {

    var micMixer: AKMixer!
    var recorder: AKNodeRecorder!
    var player: AKPlayer!
    var tape: AKAudioFile!
    var micBooster: AKBooster!
    var moogLadder: AKMoogLadder!
    var delay: AKDelay!
    var mainMixer: AKMixer!

    var mic = AKMicrophone()

    var state = State.readyToRecord

    @IBOutlet private var inputPlot: UIView!
    @IBOutlet private var outputPlot: UIView!
    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var resetButton: UIButton!
    @IBOutlet private weak var mainButton: UIButton!
    @IBOutlet private weak var loopButton: UIButton!
    

    enum State {
        case readyToRecord
        case recording
        case readyToPlay
        case playing
    }
    var once = true
    
    func setupPlot() {
        let plot = AKNodeOutputPlot(mic, frame: inputPlot.bounds)
        plot.plotType = .buffer
        plot.shouldFill = true
        plot.shouldMirror = true
        plot.color = UIColor.blue
        let label = UILabel(frame: CGRect(x: 8, y: 8, width: 40, height: 21))
        label.text = "Input"
        plot.addSubview(label)
        inputPlot.addSubview(plot)
        
    }
    
    func setupStaticPlot()
    {
        if once
        {
            let plot = AKNodeOutputPlot(player, frame: outputPlot.bounds)
            plot.plotType = .rolling
            plot.shouldFill = true
            plot.shouldMirror = true
            plot.color = UIColor.red
            let label = UILabel(frame: CGRect(x: 8, y: 8, width: 55, height: 21))
            label.text = "Input"
            plot.addSubview(label)
            outputPlot.addSubview(plot)
            once = false
        }
    }
    
    @objc func userDidSelectCancel(_ sender: AnyObject!)
    {
        mic.stop()

        //random things ive tried to remove AKMicrophone from the AK engine..
        
        /*for i in 0...2
        {
            mic.outputNode.removeTap(onBus: i)
            mic.avAudioNode.removeTap(onBus: i)
            AudioKit.engine.inputNode.disconnectInput(bus: i)
            AudioKit.engine.inputNode.removeTap(onBus: i)
            AudioKit.engine.outputNode.disconnectInput(bus: i) //this works once
            AudioKit.engine.outputNode.removeTap(onBus: i) //this works once
            mic.outputNode.removeTap(onBus: i)
            mic.avAudioNode.removeTap(onBus: i)
            AudioKit.engine.disconnectNodeInput(mic.avAudioNode)
            AudioKit.engine.disconnectNodeOutput(mic.avAudioNode)
            AudioKit.engine.disconnectNodeInput(mic.avAudioNode, bus: i)
            AudioKit.engine.disconnectNodeOutput(mic.avAudioNode, bus: i)
        }
        AudioKit.engine.detach(mic.outputNode)
        
        AudioKit.output?.disconnectOutput()
        AudioKit.disconnectAllInputs()
        AudioKit.engine.inputNode.disconnectInput()
        AudioKit.engine.inputNode.disconnectOutput()
        AudioKit.engine.stop()
        AudioKit.engine.reset()
        AKSettings.audioInputEnabled = false
        */
        
        do {try AKSettings.setSession(category: .playback, with: [])}
        catch {AKLog("Could not set session category.")}
        do {try AudioKit.stop()}
        catch {AKLog("Could not stop .")}
        print(AudioKit.engine.inputNode.connectionPoints)
        print(AudioKit.engine.outputNode.connectionPoints)
        
        //        AudioKit.output = AudioKit.output
        navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(self.userDidSelectCancel(_:)))
        
        // Clean tempFiles !
        AKAudioFile.cleanTempDirectory()

        // Session settings
        AKSettings.bufferLength = .medium

        do {try AKSettings.setSession(category: .playAndRecord, with: .allowBluetoothA2DP)}
        catch {AKLog("Could not set session category.")}

        AKSettings.defaultToSpeaker = true
        AKSettings.playbackWhileMuted = true
        
        // Patching
        micMixer = AKMixer(mic)
        micBooster = AKBooster(micMixer)

        // Will set the level of microphone monitoring
        micBooster.gain = 1
        recorder = try? AKNodeRecorder(node: micMixer)
        if let file = recorder.audioFile {player = AKPlayer(audioFile: file)}
        player.isLooping = true
        player.completionHandler = playingEnded

        moogLadder = AKMoogLadder(player)
        moogLadder.resonance = 0
        moogLadder.cutoffFrequency = 1991

        mainMixer = AKMixer(moogLadder, micBooster)

        AudioKit.output = mainMixer
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.1) {
            do{try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeDefault)}
            catch (let error) {print("Error while configuring audio session: \(error)")}
            do {try AudioKit.start()}
            catch {AKLog("AudioKit did not start!\(error)")}

            self.setupPlot()
            self.setupButtonNames()
            self.setupUIForRecording()
            self.setupStaticPlot()
        }
    }

    // CallBack triggered when playing has ended
    // Must be seipatched on the main queue as completionHandler
    // will be triggered by a background thread
    func playingEnded() {DispatchQueue.main.async {self.setupUIForPlaying ()}}

    @IBAction func mainButtonTouched(sender: UIButton) {
        switch state {
        case .readyToRecord :
            infoLabel.text = "Recording"
            mainButton.setTitle("Stop", for: .normal)
            state = .recording
            // microphone will be monitored while recording
            // only if headphones are plugged
            if AKSettings.headPhonesPlugged {micBooster.gain = 1}
            do {try recorder.record()}
            catch { print("Errored recording.") }
        case .recording :
            // Microphone monitoring is muted
            micBooster.gain = 0
            tape = recorder.audioFile!
            player.load(audioFile: tape)

            if let _ = player.audioFile?.duration {
                recorder.stop()
                tape.exportAsynchronously(name: "TempTestFile.m4a",
                                          baseDir: .documents,
                                          exportFormat: .m4a) {_, exportError in
                    if let error = exportError {print("Export Failed \(error)")}
                    else {print("Export succeeded")}
                }
                setupUIForPlaying ()
            }
        case .readyToPlay :
            player.play()
            infoLabel.text = "Playing..."
            mainButton.setTitle("Stop", for: .normal)
            state = .playing
            setupStaticPlot()
        case .playing :
            player.stop()
            setupUIForPlaying()
        }
    }

    func setupButtonNames() {
        resetButton.setTitle("", for: UIControlState.disabled)
        mainButton.setTitle("", for: UIControlState.disabled)
        loopButton.setTitle("", for: UIControlState.disabled)
    }

    func setupUIForRecording () {
        state = .readyToRecord
        infoLabel.text = "Ready to record"
        mainButton.setTitle("Record", for: .normal)
        resetButton.isEnabled = false
        resetButton.isHidden = true
        micBooster.gain = 0
        setSliders(active: false)
    }

    func setupUIForPlaying () {
        let recordedDuration = player != nil ? player.audioFile?.duration  : 0
        infoLabel.text = "Recorded: \(String(format: "%0.1f", recordedDuration!)) seconds"
        mainButton.setTitle("Play", for: .normal)
        state = .readyToPlay
        resetButton.isHidden = false
        resetButton.isEnabled = true
        setSliders(active: true)
        
    }

    func setSliders(active: Bool) {
        loopButton.isEnabled = active
    }

    @IBAction func loopButtonTouched(sender: UIButton) {
        if player.isLooping {
            player.isLooping = false
            sender.setTitle("Loop is Off", for: .normal)
        } else {
            player.isLooping = true
            sender.setTitle("Loop is On", for: .normal)
        }

    }
    @IBAction func resetButtonTouched(sender: UIButton) {
        player.stop()
        do {try recorder.reset()}
        catch { print("Errored resetting.") }

        //try? player.replaceFile((recorder.audioFile)!)
        setupUIForRecording()
    }

    override func didReceiveMemoryWarning() {super.didReceiveMemoryWarning()}
}
