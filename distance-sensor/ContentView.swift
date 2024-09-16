//
//  ContentView.swift
//  distance-sensor
//
//  Created by Fulton Browne on 9/16/24.
//

import SwiftUI
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var currentData: String?

    
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var dataCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Start scanning for devices
            centralManager.scanForPeripherals(withServices: [CBUUID(string: "dca96e5a-fe28-4697-9c1a-d67181d8fa8b")], options: nil)
        } else {
            print("Bluetooth not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([CBUUID(string: "dca96e5a-fe28-4697-9c1a-d67181d8fa8b")])
    }
    
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let services = peripheral.services {
                for service in services {
                    peripheral.discoverCharacteristics(
                        [CBUUID(string: "77eed7e7-4bf1-478d-a432-440428ed4acf")],
                        for: service
                    )
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                        error: Error?) {
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    if characteristic.uuid == CBUUID(string: "77eed7e7-4bf1-478d-a432-440428ed4acf") {
                        dataCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                        error: Error?) {
            if let data = characteristic.value, let jsonString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.currentData = jsonString
                    self.saveData(jsonString: jsonString)
                }
            }
        }

    func saveData(jsonString: String) {
        let fileName = "sensorData.txt"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            do {
                // Append data to file
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                if let data = (jsonString + "\n").data(using: .utf8) {
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } catch {
                // File doesn't exist, create it
                do {
                    try (jsonString + "\n").write(to: fileURL, atomically: false, encoding: .utf8)
                } catch {
                    print("Error writing file: \(error)")
                }
            }
        }
    }
    
}

struct ContentView: View {
    @ObservedObject var bleManager = BLEManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                if bleManager.isConnected {
                    Text("Connected to Sensor")
                        .font(.headline)
                        .foregroundColor(.green)
                } else {
                    Text("Scanning for Sensor...")
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                // Current Sensor Data
                if let jsonString = bleManager.currentData,
                   let data = parseJSON(jsonString: jsonString) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current Sensor Data:")
                            .font(.title2)
                            .bold()
                        Text("Distance: \(data.distance) cm")
                            .font(.body)
                        Text("Flux: \(data.flux)")
                            .font(.body)
                        Text("Temperature: \(data.temperature) °C")
                            .font(.body)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                } else {
                    Text("Waiting for data...")
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitle("Sensor Data")
        }
    }

    func parseJSON(jsonString: String) -> (distance: Int, flux: Int, temperature: Int)? {
        if let data = jsonString.data(using: .utf8) {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Int],
                   let distance = jsonDict["distance"],
                   let flux = jsonDict["flux"],
                   let temperature = jsonDict["temperature"] {
                    return (distance, flux, temperature)
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
        }
        return nil
    }
}
