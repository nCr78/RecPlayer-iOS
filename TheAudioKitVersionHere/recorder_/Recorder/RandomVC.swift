//
//  RandomVC.swift
//  Recorder
//
//  Created by Eleftherios Krm on 11/4/18.
//  Copyright © 2018 Eleftherios Krm. All rights reserved.
//

import Foundation
import UIKit
import AudioKit

class RandomVC: UIViewController {
    
    var mainMixer: AKMixer!
    
    @objc func userDidSelectCancel(_ sender: AnyObject!)
    {
        do {try AudioKit.stop()}
        catch {AKLog("Could not stop .")}
        print(AudioKit.engine.inputNode.connectionPoints)
        print(AudioKit.engine.outputNode.connectionPoints)

        navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(self.userDidSelectCancel(_:)))
        
        do {try AudioKit.start()}
        catch {AKLog("AudioKit did not start!")}
    }
}
