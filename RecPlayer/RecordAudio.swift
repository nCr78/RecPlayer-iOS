//
//  RecordAudio.swift
//  Recorder
//
//  Created by Eleftherios Krm on 1/4/18.
//  Copyright © 2018 Eleftherios Krm. All rights reserved.
//

import Foundation
import AVFoundation
import AudioUnit

// call setupAudioSessionForRecording() during controlling view load
// call startRecording() to start recording in a later UI call
let circBuffSize = 4 * 32768        // lock-free circular fifo/buffer size
final class RecordAudio: NSObject {
    
    var audioUnit:   AudioUnit?     = nil
    
    var sampleRate : Double = 48000.0    // default audio sample rate
    var micPermission   =  false
    var sessionActive   =  false
    var isRecording     =  false
    
    var circBuffer   = [Float](repeating: 0, count: circBuffSize)  // for incoming samples
    var circInIdx  : Int =  0
    
    private var hwSRate = 48000.0   // guess of device hardware sample rate
    private var micPermissionDispatchToken = 0
    private var interrupted = false     // for restart from audio interruption notification
    
    func startRecording() {
        if isRecording { return }
        
        startAudioSession()
        if sessionActive {
            startAudioUnit()
        }
    }
    
    var numberOfChannels: Int       =  2
    
    private let outputBus: UInt32   =  0
    private let inputBus: UInt32    =  1
    
    func startAudioUnit() {
        var err: OSStatus = noErr
        
        if self.audioUnit == nil {
            setupAudioUnit()         // setup once
        }
        guard let au = self.audioUnit
            else { return }
        
        err = AudioUnitInitialize(au)
        gTmp0 = Int(err)
        if err != noErr { return }
        err = AudioOutputUnitStart(au)  // start
        
        gTmp0 = Int(err)
        if err == noErr {
            isRecording = true
        }
    }
    
    func startAudioSession() {
        if (sessionActive == false) {
            // set and activate Audio Session
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                if (micPermission == false) {
                    if (micPermissionDispatchToken == 0) {
                        micPermissionDispatchToken = 1
                        audioSession.requestRecordPermission({(granted: Bool)-> Void in
                            if granted {
                                self.micPermission = true
                                return
                                // check for this flag and call from UI loop if needed
                            } else {
                                gTmp0 += 1
                                // dispatch in main/UI thread an alert
                                //   informing that mic permission is not switched on
                            }
                        })
                    }
                }
                if micPermission == false { return }
                
                try audioSession.setCategory(AVAudioSessionCategoryRecord,
                                             mode: AVAudioSessionModeMeasurement,
                                             options: [])
                
                // choose 44100 or 48000 based on hardware rate
                var preferredIOBufferDuration = 0.0053      // 5.3 milliseconds = 256 samples
                hwSRate = audioSession.sampleRate           // get native hardware rate
                if hwSRate == 44100.0 { sampleRate = 44100.0 }  // set session to hardware rate
                if hwSRate == 44100.0 { preferredIOBufferDuration = 0.0058 } // for old devices
                let desiredSampleRate = sampleRate
                try audioSession.setPreferredSampleRate(desiredSampleRate)
                try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)
                
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name.AVAudioSessionInterruption,
                    object: nil,
                    queue: nil,
                    using: myAudioSessionInterruptionHandler )
                
                try audioSession.setActive(true)
                sessionActive = true
            } catch /* let error as NSError */ {
                // handle error here
            }
        }
    }
    
    private func setupAudioUnit() {
        
        var componentDesc:  AudioComponentDescription
            = AudioComponentDescription(
                componentType:          OSType(kAudioUnitType_Output),
                componentSubType:       OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer:  OSType(kAudioUnitManufacturer_Apple),
                componentFlags:         UInt32(0),
                componentFlagsMask:     UInt32(0) )
        
        var osErr: OSStatus = noErr
        
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        
        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit
        
        guard let au = self.audioUnit
            else { return }
        
        // Enable I/O for input.
        
        var one_ui32: UInt32 = 1
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        
        // Set format to 32-bit Floats, linear PCM
        let nc = 2  // 2 channel stereo
        var streamFormatDesc:AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate:        Double(sampleRate),
            mFormatID:          kAudioFormatLinearPCM,
            mFormatFlags:       ( kAudioFormatFlagsNativeFloatPacked ),
            mBytesPerPacket:    UInt32(nc * MemoryLayout<Float>.size),
            mFramesPerPacket:   1,
            mBytesPerFrame:     UInt32(nc * MemoryLayout<Float>.size),
            mChannelsPerFrame:  UInt32(nc),
            mBitsPerChannel:    UInt32(8 * (MemoryLayout<Float>.size)),
            mReserved:          UInt32(0)
        )
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input, outputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon:
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Ask CoreAudio to allocate buffers for us on render.
        //   Is this true by default?
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        gTmp0 = Int(osErr)
    }
    
    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        ioData ) -> OSStatus in
        
        let audioObject = unsafeBitCast(inRefCon, to: RecordAudio.self)
        var err: OSStatus = noErr
        
        // set mData to nil, AudioUnitRender() should be allocating buffers
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(2),
                mDataByteSize: 16,
                mData: nil))
        
        if let au = audioObject.audioUnit {
            err = AudioUnitRender(au,
                                  ioActionFlags,
                                  inTimeStamp,
                                  inBusNumber,
                                  frameCount,
                                  &bufferList)
        }
        
        audioObject.saveRecordedSamples( inputDataList: &bufferList,
                                         frameCount: UInt32(frameCount) )
        
        return 0
    }
    
    func saveRecordedSamples(   // save RemoteIO mic input samples
        inputDataList : UnsafeMutablePointer<AudioBufferList>,
        frameCount : UInt32 )
    {
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers : AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)
        
        // from Microphone Input
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            var j = self.circInIdx
            let m = circBuffSize
            for i in 0..<(count) {
                let x = Float(dataArray[i+i  ])   // copy left  channel sample
                let y = Float(dataArray[i+i+1])   // copy right channel sample
                circBuffer[j    ] = x
                circBuffer[j + 1] = y
                j += 2 ; if j >= m { j = 0 }                // into circular buffer
            }
            self.circInIdx = j              // circular index will always be less than size
        }
    }
    
    func stopRecording() {
        AudioUnitUninitialize(self.audioUnit!)
        isRecording = false
    }
    
    func myAudioSessionInterruptionHandler(notification: Notification) -> Void {
        let interuptionDict = notification.userInfo
        if let interuptionType = interuptionDict?[AVAudioSessionInterruptionTypeKey] {
            let interuptionVal = AVAudioSessionInterruptionType(
                rawValue: (interuptionType as AnyObject).uintValue )
            if (interuptionVal == AVAudioSessionInterruptionType.began) {
                if (isRecording) {
                    stopRecording()
                    isRecording = false
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(false)
                        sessionActive = false
                    } catch {
                    }
                    interrupted = true
                }
            } else if (interuptionVal == AVAudioSessionInterruptionType.ended) {
                if (interrupted) {
                    // potentially restart here
                    startRecording()
                }
            }
        }
    }
}
