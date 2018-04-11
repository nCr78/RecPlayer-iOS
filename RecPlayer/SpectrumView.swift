//
//  SpectrumView.swift
//  Recorder
//
//  Created by Eleftherios Krm on 1/4/18.
//  Copyright © 2018 Eleftherios Krm. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

var gTmp0 = 0 // debug

class SpectrumView: UIView {
    
    let bitmapWidth  = 256
    let bitmapHeight = 256
    
    var slowSpectrumArray = [Float](repeating: 0.0, count: Int(UIScreen.main.bounds.width))
    var spectrumArray = [Float](repeating: 0, count: Int(UIScreen.main.bounds.width))
    let fftLen = 8 * 256
    
    var minx : Float =  1.0e12
    var maxx : Float = -1.0e12
    
    var fftSetup : FFTSetup? = nil
    var auBWindow = [Float](repeating: 1.0, count: 32768)
    
    override func draw(_ rect: CGRect) {
        let context : CGContext! = UIGraphicsGetCurrentContext()
        let r0 : CGRect!            = self.bounds
        if true {                                    // ** Rect **
            context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0);
            context.fill(r0);
        }
        
        let n = Int(UIScreen.main.bounds.width)
        let array = spectrumArray
        let r : Float = 0.25
        for i in 0 ..< n {
            slowSpectrumArray[i] = r * array[i] + (1.0 - r) * slowSpectrumArray[i]
        }
        
        context.setFillColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0);
        let h0 = CGFloat(r0.size.height)
        let dx = (r0.size.width) / CGFloat(n)
        if array.count >= n {
            for i in 0 ..< n  {
                let y = h0 * CGFloat(1.0 - slowSpectrumArray[i])
                let x = r0.origin.x + CGFloat(i) * dx
                let h = h0 - y
                let w = dx
                // let r1  = CGRect(x: x + 20, y: y, width: w, height: h)
                let r1  = CGRect(x: x, y: y, width: w, height: h)
                context.stroke(r1, width: 0.15)
                context.setStrokeColor(red: 0.2, green: 0.2, blue: 1.0, alpha: 1.0);
                context.fill(r1)
            }
        }
    }
    
    func doFFT_OnAudioBuffer(_ audioObject : RecordAudio) -> ([Float]) {
        
        let log2N = UInt(round(log2f(Float(fftLen))))
        var output = [Float](repeating: 0.0, count: fftLen)
        
        guard let myAudio = globalAudioRecorder
            else { return output }
        
        if fftSetup == nil {
            fftSetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
            vDSP_blkman_window(&auBWindow, vDSP_Length(fftLen), 0)
        }
        
        var fcAudioU0 = [Float](repeating: 0.0, count: fftLen)
        var fcAudioV0 = [Float](repeating: 0.0, count: fftLen)
        var i = myAudio.circInIdx - 2 * fftLen
        if i < 0 { i += circBuffSize }
        for j in 0 ..< fftLen {
            if i < 0 {gTmp0 = 0}
            if i >= circBuffSize {gTmp0 = 0}
            fcAudioU0[j] = audioObject.circBuffer[i]
            i += 2 ; if i >= circBuffSize { i -= circBuffSize } // circular buffer
        }
        
        vDSP_vmul(fcAudioU0, 1, auBWindow, 1, &fcAudioU0, 1, vDSP_Length(fftLen/2))
        
        var fcAudioUV = DSPSplitComplex(realp: &fcAudioU0,  imagp: &fcAudioV0 )
        vDSP_fft_zip(fftSetup!, &fcAudioUV, 1, log2N, Int32(FFT_FORWARD)); //  FFT()
        
        var tmpAuSpectrum = [Float](repeating: 0.0, count: fftLen)
        vDSP_zvmags(&fcAudioUV, 1, &tmpAuSpectrum, 1, vDSP_Length(fftLen/2))  // abs()
        
        var scale = 1024.0 / Float(fftLen)
        vDSP_vsmul(&tmpAuSpectrum, 1, &scale, &output, 1, vDSP_Length(fftLen/2))
        
        return (output)
    }
    
    func makeSpectrumFromAudio(_ audioObject: RecordAudio) {
        
        var magnitudeArray = doFFT_OnAudioBuffer(audioObject)
        
        for i in 0 ..< Int(UIScreen.main.bounds.width) {
            if i < magnitudeArray.count {
                var x = (1024.0 + 64.0 * Float(i)) * magnitudeArray[i]
                if x > maxx { maxx = x }
                if x < minx { minx = x }
                var y : Float = 0.0
                if (x > minx) {
                    if (x < 1.0) { x = 1.0 }
                    let r = (logf(maxx - minx) - logf(1.0)) * 1.0
                    let u = (logf(x    - minx) - logf(1.0))
                    y = u / r
                }
                spectrumArray[i] = y
            }
        }
    }
}
