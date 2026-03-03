//
//  BLEManager.swift
//  SonyCameraLocation
//
//  CoreBluetooth 掃描、連線、寫入管理
//

import CoreBluetooth
import CoreLocation
import Observation

struct DiscoveredDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    let isSonyCamera: Bool
}

enum BLEState {
    case unknown, unsupported, unauthorized, poweredOff, poweredOn
    case scanning, connecting, connected, disconnected

    var displayText: String {
        switch self {
        case .unknown: return "未知"
        case .unsupported: return "不支援藍牙"
        case .unauthorized: return "藍牙未授權"
        case .poweredOff: return "藍牙已關閉"
        case .poweredOn: return "藍牙已開啟"
        case .scanning: return "掃描中..."
        case .connecting: return "連線中..."
        case .connected: return "已連線"
        case .disconnected: return "已斷線"
        }
    }
}

@Observable
final class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var connectionTestChar: CBCharacteristic?
    private var gpsWriteChar: CBCharacteristic?
    private var transmitTimer: Timer?

    var bleState: BLEState = .unknown
    var discoveredDevices: [DiscoveredDevice] = []
    var isConnected = false
    var isCameraOn = false
    var isTransmitting = false
    var packetsSent = 0
    var packetsError = 0
    var lastError: String?
    var connectedDeviceName: String?

    var locationProvider: (() -> CLLocation?)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices = []
        bleState = .scanning
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScanning() {
        centralManager.stopScan()
        if bleState == .scanning {
            bleState = .poweredOn
        }
    }

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        bleState = .connecting
        connectedDeviceName = device.name
        centralManager.connect(device.peripheral, options: nil)
        connectedPeripheral = device.peripheral
        device.peripheral.delegate = self
    }

    func disconnect() {
        stopTransmitting()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetConnectionState()
    }

    func startTransmitting() {
        guard isConnected, isCameraOn, gpsWriteChar != nil else { return }
        isTransmitting = true
        transmitTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendGPSPacket()
        }
    }

    func stopTransmitting() {
        transmitTimer?.invalidate()
        transmitTimer = nil
        isTransmitting = false
    }

    // MARK: - Private

    private func sendGPSPacket() {
        guard let peripheral = connectedPeripheral,
              let char = gpsWriteChar,
              let location = locationProvider?() else { return }

        let packet = GPSPacketEncoder.encode(location: location)
        peripheral.writeValue(packet, for: char, type: .withResponse)
    }

    private func resetConnectionState() {
        connectedPeripheral = nil
        connectionTestChar = nil
        gpsWriteChar = nil
        connectedDeviceName = nil
        isConnected = false
        isCameraOn = false
        isTransmitting = false
        bleState = .poweredOn
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bleState = .poweredOn
        case .poweredOff:
            bleState = .poweredOff
            resetConnectionState()
        case .unauthorized:
            bleState = .unauthorized
        case .unsupported:
            bleState = .unsupported
        default:
            bleState = .unknown
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "未知裝置"
        let isSony = GATTConstants.cameraNameKeywords.contains { name.contains($0) }

        if discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
            discoveredDevices = discoveredDevices.map { d in
                if d.id == peripheral.identifier {
                    return DiscoveredDevice(id: d.id, name: name, rssi: RSSI.intValue,
                                           peripheral: peripheral, isSonyCamera: isSony)
                }
                return d
            }
        } else {
            let device = DiscoveredDevice(id: peripheral.identifier, name: name,
                                          rssi: RSSI.intValue, peripheral: peripheral,
                                          isSonyCamera: isSony)
            discoveredDevices.append(device)
            discoveredDevices.sort { $0.rssi > $1.rssi }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        bleState = .connected
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        lastError = "連線失敗：\(error?.localizedDescription ?? "未知錯誤")"
        resetConnectionState()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        stopTransmitting()
        resetConnectionState()
        bleState = .disconnected
        if error != nil {
            lastError = "連線中斷"
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(
                [GATTConstants.connectionTestUUID, GATTConstants.gpsWriteUUID],
                for: service
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == GATTConstants.connectionTestUUID {
                connectionTestChar = char
                peripheral.readValue(for: char)
            } else if char.uuid == GATTConstants.gpsWriteUUID {
                gpsWriteChar = char
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == GATTConstants.connectionTestUUID,
              let data = characteristic.value else { return }

        // 最後 1 byte = 0x00 表示相機開機
        isCameraOn = data.last == 0x00
        if !isCameraOn {
            stopTransmitting()
            lastError = "相機未開機（請確認相機電源）"
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            packetsError += 1
            lastError = "傳送失敗：\(error.localizedDescription)"
        } else {
            packetsSent += 1
            lastError = nil
        }
    }
}
