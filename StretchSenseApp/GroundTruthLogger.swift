//
//  GroundTruthLogger.swift
//  StretchSenseApp
//
//  Created by Justin Whitlock on 3/7/18.
//  Copyright © 2018 Justin Whitlock. All rights reserved.
//

import Cocoa

class GroundTruthLogger: NSObject {
    var file: FileHandle!;
    let formatter = DateFormatter();
    let nc = NotificationCenter.default;
    
    init(date: String = "unknown") {
        super.init();
        print("### GTLogger DateString:: " + date);
        
        do {
            // determine if the log file exists
            let fileManager = FileManager.default;
            let fileDirUrl = URL(string: fileManager.homeDirectoryForCurrentUser.absoluteString + "Desktop/Data");
            let fileNameUrl = URL(string: fileManager.homeDirectoryForCurrentUser.absoluteString + "Desktop/Data/GT_" + date + ".csv");
            var isDirectory = ObjCBool(true)
            let exists = fileManager.fileExists(atPath: fileDirUrl!.path, isDirectory: &isDirectory);
            if( !exists || !isDirectory.boolValue){
                try fileManager.createDirectory(at: (fileDirUrl)!, withIntermediateDirectories: false, attributes: nil);
                nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"Directory Created"])
                
            }
            
            if (fileManager.fileExists(atPath: fileNameUrl!.path)) {
                do {
                    try fileManager.removeItem(atPath: fileNameUrl!.path)
                } catch {
                    print("ERROR:: unable to remove GroundTruth data");
                    nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"ERROR:: unable to remove GroundTruth data"])
                    print(error.localizedDescription);
                }
            }
            
            fileManager.createFile(atPath: fileNameUrl!.path, contents: nil, attributes: nil);
            do{
                file = try FileHandle(forWritingTo: fileNameUrl!);
            }catch{
                nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"###FILE HANDLE EXCEPTION: " + (fileNameUrl)!.absoluteString])
                print("###FILE HANDLE EXCEPTION: " + (fileNameUrl)!.absoluteString);
            }
            file.write("Time,Label\n".data(using: String.Encoding.utf8, allowLossyConversion: false)!);
            
        } catch {
            print(error.localizedDescription);
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"ERROR:: unable to write GT data"])
        }
    }
    
    func writeData(GTEntry : String) {
        file.seekToEndOfFile();
        let toWrite = GTEntry + "\n";
        file.write(toWrite.data(using: String.Encoding.utf8, allowLossyConversion: false)!);
    }
    
    deinit {
        let toWrite = "Logging Ends," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
        writeData(GTEntry: toWrite);
        file.closeFile();
    }
    
}
