import Foundation

class DataLogger: NSObject {
    
    var counter:Int = 0;
    var file: FileHandle!;
    let formatter = DateFormatter();
    let nc = NotificationCenter.default;
    

    init(date: String = "unknown") {
        super.init();
        print("### DataLogger DateString:: " + date);
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"Init DataLogger"])
        do {
            // determine if the log file exists
            let fileManager = FileManager.default;
            let fileDirUrl = URL(string: fileManager.homeDirectoryForCurrentUser.absoluteString + "Desktop/Data");
            let fileNameUrl = URL(string: fileManager.homeDirectoryForCurrentUser.absoluteString + "Desktop/Data/CAP_" + date + ".csv");
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
                    print("ERROR:: unable to remove old capacitance data");
                    nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"ERROR:: unable to remove old capacitance data"])
                    print(error.localizedDescription);
                }
            }
            
            fileManager.createFile(atPath: fileNameUrl!.path, contents: nil, attributes: nil);
            file = try FileHandle(forWritingTo: fileNameUrl!);
            file.write("pF,time\n".data(using: String.Encoding.utf8, allowLossyConversion: false)!);
        } catch {
            print(error.localizedDescription);
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"ERROR:: unable to write cap data"])
        }
    }
    
    func writeStretchSenseData(stretchSenseEntry : String) {
        file.seekToEndOfFile();
        let toWrite = stretchSenseEntry + "\n";
        file.write(toWrite.data(using: String.Encoding.utf8, allowLossyConversion: false)!);
    }
    
    deinit {
        file.closeFile();
    }
    
}

