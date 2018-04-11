//
//  AppDelegate.swift
//  Recorder
//
//  Created by Eleftherios Krm on 31/3/18.
//  Copyright © 2018 Eleftherios Krm. All rights reserved.
//

import UIKit

var globalAudioRecorder : RecordAudio? = nil
var audioKitStarted = false

@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {
                            
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}
}
