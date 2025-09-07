import CoreBluetooth

class BLEPeripheralManager: NSObject, CBPeripheralManagerDelegate {
    var peripheralManager: CBPeripheralManager?
    let serviceUUID = CBUUID(string: "0000180D-0000-1000-8000-00805f9b34fb")

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            stopAdvertising()
        }
    }

    func startAdvertising() {
        let advertisementData = [CBAdvertisementDataServiceUUIDsKey: [serviceUUID]]
        peripheralManager?.startAdvertising(advertisementData)
        print("Started advertising with service UUID: \(serviceUUID)")
    }

    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        print("Stopped advertising")
    }
}
