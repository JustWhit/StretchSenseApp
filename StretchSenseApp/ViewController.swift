//
//  ViewController.swift
//  StretchSenseApp
//
//  Created by Justin Whitlock on 3/7/18.
//  Copyright © 2018 Justin Whitlock. All rights reserved.
//

import Cocoa
import AVFoundation


class ViewController: NSViewController {
    private var logging = false;
    private var discarding = false;
    var worker = BluetoothWorker();
    var audioRecorder = AVAudioRecorder();
    
    
    let defaultCenter = NotificationCenter.default;
    
    
    @IBOutlet weak var EnterActivity: NSTextField!
    
    @IBAction func CapLogClicked(_ sender: NSButton) {
        if(!logging){
            worker.startLogging();
            logging = true;
            sender.title = "Stop Logging";
        }
        else{
            logging = false;
            sender.title = "Start Logging";
            stopLogging();
            
        }
        
    }
    
    @IBAction func NoteClicked(_ sender: NSButton) {
        let toWrite = "Note," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
        worker.GTlogger.writeData(GTEntry: toWrite);
    }
    
    
    @IBAction func DiscardClicked(_ sender: NSButton) {
        if(!discarding){
            let toWrite = "BeginDiscard," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
            worker.GTlogger.writeData(GTEntry: toWrite);
            sender.title = "Stop Discarding";
            discarding = true;
        }
        else{
            let toWrite = "StopDiscard," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
            worker.GTlogger.writeData(GTEntry: toWrite);
            sender.title = "Discard";
            discarding = false;
        }
    }
    
    
    @IBOutlet weak var infoText: NSTextField!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ready for receiving notification
        
        defaultCenter.addObserver(forName:Notification.Name(rawValue: "SSInfoUpdate"),object:nil, queue:nil){
            notification in
            guard let userInfo = notification.userInfo,
                let message  = userInfo["message"] as? String else {
                    print("No userInfo found in notification")
                    return
            }
            DispatchQueue.main.async { // Correct
                self.infoText.stringValue = message;
            }
            
            
        }
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func startCapLog(){
        self.worker.startLogging();
    }
    
    func stopLogging(){
        self.worker = BluetoothWorker();
    }


}

