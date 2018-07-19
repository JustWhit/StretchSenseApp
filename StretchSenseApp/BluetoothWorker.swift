import Foundation

import CoreBluetooth;


class BluetoothWorker: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var dataUUIDgen2 = CBUUID(string: "00001502-7374-7265-7563-6873656e7365")
    let heartRateMeasurementCBUUID = CBUUID(string: "2A37");
    let bodysensorLocationCBUUID = CBUUID(string: "2A38");
    
    var manager = CBCentralManager();
    var myPherif: CBPeripheral?;
    var myHeart: CBPeripheral?;
    var heartfound = false;
    var pheriffound = false;
    var heartRate = 0;
    
    let queue = DispatchQueue(label: "com.my.queue");
    let formatter = DateFormatter();
    
    let capacitor = "StretchSense";
    let Polar = "Polar H10 25E71E23";
    
    var totalSample : Int = 0;
    var logger : DataLogger;
    var GTlogger : GroundTruthLogger;
    let nc = NotificationCenter.default;

    
    override init() {
        formatter.dateFormat = "yyyy-MM-dd";
        let current = Date();
        let date = String(formatter.string(from: current)) + String(Int(Float(NSDate.timeIntervalSinceReferenceDate)));
        
        print("## " + date);
        logger = DataLogger(date:date);
        GTlogger = GroundTruthLogger(date:date);
        super.init();
        //manager = CBCentralManager(delegate: self, queue: queue);
    }
    
    
    func startLogging(){
        manager = CBCentralManager(delegate: self, queue: queue);
        print("## startLogging");
    }
    
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state{
            
        case .unknown:
            print("##### central state is UNKNOWN");
        case .resetting:
            print("##### central state is RESETTING");
        case .unsupported:
            print("##### central state is UNSUPPORTED");
        case .unauthorized:
            print("##### central state is UNAUTHORIZED");
        case .poweredOff:
            print("##### bluetooth is disabled");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"##### bluetooth is disabled"])
            manager.stopScan();
        case .poweredOn:
            print("### bluetooth is enabled, starting scan");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"### bluetooth is enabled, starting scan"])
            
            manager.scanForPeripherals(withServices: nil);
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        if (peripheral.name != nil && peripheral.name! == capacitor) {
            print("## stretchsense found, attaching and searching for details");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"## stretchsense found, attaching and searching for details"])
            
            myPherif = peripheral;
            myPherif?.delegate = self;
            self.manager.connect(myPherif!);
            peripheral.discoverServices(nil);
        }
        if (peripheral.name != nil && peripheral.name! == Polar){
            print("## Polar Heart Sensor found, attaching and searching for details");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"## Polar Heart Sensor found, attaching and searching for details"])
            
            myHeart = peripheral;
            myHeart?.delegate = self;
            self.manager.connect(myHeart!);
            peripheral.discoverServices(nil);
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("### attached to ",peripheral.name!, ", looking for its services");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message": String("### attached to " + peripheral.name! + ", looking for its services")])
        if(peripheral.name! == capacitor && pheriffound == false){
            pheriffound = true;
        }
        if(peripheral.name! == Polar && heartfound == false){
            heartfound = true;
        }
        if(pheriffound && heartfound){
            manager.stopScan();
        }
        //peripheral.delegate = self;
        peripheral.discoverServices(nil);
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("## found services in stretchsense, looking for its characteristics");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"## found services in stretchsense, looking for its characteristics"])
        guard let services = peripheral.services else {return}
        
        for service in services {
            let foundService = service as CBService;
            peripheral.discoverCharacteristics(nil, for: foundService);
            print(service);
        }
        
        print("## Logging Begins");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"### Sensor Connected, Begin Logging"])
        let toWrite = "Logging Begins," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
        GTlogger.writeData(GTEntry: toWrite);
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else{return}
        
        for characteristic in characteristics {
            print(characteristic);
            let foundCharacteristic = characteristic as CBCharacteristic;
            let foundCharacteristicStrng = foundCharacteristic.uuid.uuidString;
            if ( foundCharacteristicStrng ==  dataUUIDgen2.uuidString ) {
                peripheral.setNotifyValue(true, for: foundCharacteristic);
                print("## capacitance characteristic found");
                
            }
            if(foundCharacteristicStrng == heartRateMeasurementCBUUID.uuidString){
                peripheral.setNotifyValue(true, for: foundCharacteristic);
                print("## heartrate characteristic found");
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid{
        case dataUUIDgen2:
                if(heartRate == 0){
                    print("## WAITING FOR HEART RATE");
                    nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"WAITING FOR HEART RATE"])
                    return;
                }
                let value = characteristic.value!;
                let valueIntSense:Int! = Int(value.hexadecimalString()!, radix: 16)!;
                let valueGen2 = CGFloat(convertRawDataToCapacitance(valueIntSense));
            
                totalSample += 1;
                let toWrite = "\(heartRate),\(valueGen2)," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
            
                DispatchQueue.global().async {
                    self.logger.writeStretchSenseData(stretchSenseEntry: toWrite);
                }
            
        case heartRateMeasurementCBUUID:
            heartRate = HeartRateHelper(from: characteristic)
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message": "Heart Rate: \(heartRate)"])
            
        default:
            return;
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("## Peripheral " + peripheral.name! + " disconnected");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"EXIT WITH ERROR?"])
        if(peripheral.name! == Polar){
            heartfound = false;
        }
        if(peripheral.name! == capacitor){
            pheriffound = false;
        }
        
    }
    
    func convertRawDataToCapacitance(_ rawDataInt: Int) -> Float{
        // Capacitance(pF) = RawData * 0.10pF
        return Float(rawDataInt) * 0.10;
    }
    
    deinit{
        if myPherif != nil{
             manager.cancelPeripheralConnection(myPherif!);
        }
        
    }
    
    private func HeartRateHelper( from characteristic: CBCharacteristic)->Int{
        guard let characteristicData = characteristic.value else{return -1}
        let byteArray = [UInt8](characteristicData)
        
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            //Heart Rate Value Format is in the 2nd byte
            return Int(byteArray[1])
        }else{
            //heart rate vale is in the 2nd and 3rd bytes
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
        }
    }
    
    
}

extension Data {
    
    func hexadecimalString() -> String? {
        if let buffer = Optional((self as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.count)) {
            var hexadecimalString = String()
            for i in 0..<self.count {
                hexadecimalString += String(format: "%02x", buffer.advanced(by: i).pointee);
            }
            return hexadecimalString;
        }
        return nil;
    }
}
