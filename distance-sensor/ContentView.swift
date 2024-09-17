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
    @Published var isRecording = false


    
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var dataCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func addTimeStampToJSON(jsonString: String) -> String? {
        if var jsonDict = try? JSONSerialization.jsonObject(with: Data(jsonString.utf8), options: []) as? [String: Any] {
            let timeStamp = Date().timeIntervalSince1970 * 1000 // Current UTC timestamp in milliseconds
            jsonDict["timeStamp"] = Int(timeStamp)
            
            if let updatedData = try? JSONSerialization.data(withJSONObject: jsonDict, options: []),
               let updatedJsonString = String(data: updatedData, encoding: .utf8) {
                return updatedJsonString
            }
        }
        return nil
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
                // Add timestamp to the JSON string
                if let jsonWithTimestamp = self.addTimeStampToJSON(jsonString: jsonString) {
                    self.currentData = jsonWithTimestamp
                    self.saveData(jsonString: jsonWithTimestamp)
                } else {
                    print("Error adding timestamp to JSON")
                }
            }
        }
    }
        
        
    func saveData(jsonString: String) {
        let fileName = "sensorData.txt"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // File URL in the Documents directory
            let fileURL = dir.appendingPathComponent(fileName)
            
            do {
                // Append data to file if it exists, else create a new file
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    if let data = (jsonString + "\n").data(using: .utf8) {
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try (jsonString + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
                }
                print("Data saved to \(fileURL.path)")
            } catch {
                print("Error writing file: \(error)")
            }
        }
    }
    
    func startRecording() {
            isRecording = true
            print("Recording started.")
        }
        
    func stopRecording() {
        isRecording = false
        print("Recording stopped.")
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
                
                // Start/Stop Recording Button
                Button(action: {
                    if bleManager.isRecording {
                        bleManager.stopRecording()
                    } else {
                        bleManager.startRecording()
                    }
                }) {
                    Text(bleManager.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(bleManager.isRecording ? Color.red : Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                
                // Display Recording Status
                Text(bleManager.isRecording ? "Recording in progress..." : "Not recording.")
                    .foregroundColor(bleManager.isRecording ? .green : .gray)
                    .font(.subheadline)

                Spacer()
            }
            .padding()
            .navigationBarTitle("Sensor Data")
        }
    }
    
    func parseJSON(jsonString: String) -> (distance: Int, flux: Int, temperature: Int, timeStamp: Int)? {
        if let data = jsonString.data(using: .utf8) {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let distance = jsonDict["distance"] as? Int,
                   let flux = jsonDict["flux"] as? Int,
                   let temperature = jsonDict["temperature"] as? Int,
                   let timeStamp = jsonDict["timeStamp"] as? Int {
                    return (distance, flux, temperature, timeStamp)
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
        }
        return nil
    }
}
