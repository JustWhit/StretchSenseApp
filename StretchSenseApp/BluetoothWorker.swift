import Foundation

import CoreBluetooth;


class BluetoothWorker: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var dataUUIDgen2 = CBUUID(string: "00001502-7374-7265-7563-6873656e7365")
    
    var manager = CBCentralManager();
    var myPherif: CBPeripheral?;
    
    let queue = DispatchQueue(label: "com.my.queue");
    let formatter = DateFormatter();
    
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
        if (central.state == .poweredOn) {
            print("### bluetooth is enabled, starting scan");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"### bluetooth is enabled, starting scan"])
            
            manager.scanForPeripherals(withServices: nil, options: nil);
        } else {
            print("##### bluetooth is disabled");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"##### bluetooth is disabled"])
            manager.stopScan();
        }
    
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (peripheral.name != nil && peripheral.name! == "StretchSense") {
            print("## stretchsense found, attaching and searching for details");
            nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"## stretchsense found, attaching and searching for details"])
            manager.stopScan();
            myPherif = peripheral;
            self.manager.connect(peripheral, options: nil);
            peripheral.discoverServices(nil);
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("### attached to stretchsense, looking for its services");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"### attached to stretchsense, looking for its services"])
        manager.stopScan();
        peripheral.delegate = self;
        peripheral.discoverServices(nil);
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("## found services in stretchsense, looking for its characteristics");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"## found services in stretchsense, looking for its characteristics"])
        for service in peripheral.services! {
            let foundService = service as CBService;
            peripheral.discoverCharacteristics(nil, for: foundService);
            print("## services");
        }
        
        print("## Logging Begins");
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"### Sensor Connected, Begin Logging"])
        let toWrite = "Logging Begins," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
        GTlogger.writeData(GTEntry: toWrite);
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("## characteristics found");
        
        for characteristic in service.characteristics! {
            let foundCharacteristic = characteristic as CBCharacteristic;
            let foundCharacteristicStrng = foundCharacteristic.uuid.uuidString;
            if ( foundCharacteristicStrng ==  dataUUIDgen2.uuidString ) {
                peripheral.setNotifyValue(true, for: foundCharacteristic);
                print("## expected characteristic found");
                
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let value = characteristic.value!;
        let valueIntSense:Int! = Int(value.hexadecimalString()!, radix: 16)!;
        let valueGen2 = CGFloat(convertRawDataToCapacitance(valueIntSense));
        
        totalSample += 1;
        let toWrite = "\(valueGen2)," + String(format:"%f", (NSDate.timeIntervalSinceReferenceDate));
        
        DispatchQueue.global().async {
            self.logger.writeStretchSenseData(stretchSenseEntry: toWrite);
        }

    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        nc.post(name:Notification.Name(rawValue:"SSInfoUpdate"), object:nil, userInfo: ["message":"EXIT WITH ERROR?"])
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
