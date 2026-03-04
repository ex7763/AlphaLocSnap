//
//  BLEManager.swift
//  SonyCameraLocation
//
//  CoreBluetooth 掃描、連線、寫入管理
//  支援 State Restoration、背景自動重連
//
//  連線流程（參考 Alpha-GPS 協定）：
//    connect → discoverServices(nil)
//      → discoverCharacteristics
//      → readValue(dd21)       // 偵測時區支援
//      → write 0x01 → dd30    // Unlock GPS
//      → write 0x01 → dd31    // Lock GPS
//      → write timeSync → cc13 (optional)
//      → isCameraOn = true     // GPS 就緒

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

/// GPS 啟用序列的狀態機
private enum SetupPhase {
    case idle
    case discoveringServices
    case readingTimezone
    case unlockingGPS
    case lockingGPS
    case syncingTime
    case ready
}

private let kRestorationIdentifier = "com.hsupc.SonyCameraLocation.central"
private let kPairedPeripheralUUIDKey = "pairedPeripheralUUID"

@Observable
final class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var setupPhase: SetupPhase = .idle

    // MARK: - Characteristics

    private var gpsWriteChar: CBCharacteristic?
    private var timezoneReadChar: CBCharacteristic?
    private var unlockGPSChar: CBCharacteristic?
    private var lockGPSChar: CBCharacteristic?
    private var timeSyncChar: CBCharacteristic?
    private var locationEnabledChar: CBCharacteristic?

    // MARK: - Public State

    var bleState: BLEState = .unknown
    var discoveredDevices: [DiscoveredDevice] = []
    var isConnected = false
    var isCameraOn = false
    var isTransmitting = false
    var supportsDST = true
    var packetsSent = 0
    var packetsError = 0
    var lastError: String?
    var connectedDeviceName: String?
    var autoConnectEnabled = true

    var locationProvider: (() -> CLLocation?)?

    /// 連線成功且 GPS 就緒回調（裝置名稱）
    @ObservationIgnored
    var onConnect: ((String) -> Void)?

    /// 斷線回調（裝置名稱）
    @ObservationIgnored
    var onDisconnect: ((String) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: kRestorationIdentifier
            ]
        )
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
        connectPeripheral(device.peripheral)
        savePairedPeripheral(device.peripheral.identifier)
    }

    func disconnect() {
        autoConnectEnabled = false
        stopTransmitting()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        clearPairedPeripheral()
        resetConnectionState()
    }

    func startTransmitting() {
        guard isConnected, isCameraOn, gpsWriteChar != nil else { return }
        isTransmitting = true
    }

    func stopTransmitting() {
        isTransmitting = false
    }

    /// 由 AppModel 的 onLocationUpdate 呼叫，取代 Timer
    func sendGPSPacket() {
        guard let peripheral = connectedPeripheral,
              let char = gpsWriteChar,
              let location = locationProvider?() else { return }

        let packet = GPSPacketEncoder.encode(location: location, supportsDST: supportsDST)
        peripheral.writeValue(packet, for: char, type: .withResponse)
    }

    /// App 啟動時嘗試重連已配對裝置
    func attemptAutoReconnect() {
        guard autoConnectEnabled,
              let uuidString = UserDefaults.standard.string(forKey: kPairedPeripheralUUIDKey),
              let uuid = UUID(uuidString: uuidString) else { return }

        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            bleState = .connecting
            connectedDeviceName = peripheral.name ?? "Sony 相機"
            connectPeripheral(peripheral)
        }
    }

    // MARK: - Private Helpers

    private func connectPeripheral(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    private func savePairedPeripheral(_ uuid: UUID) {
        UserDefaults.standard.set(uuid.uuidString, forKey: kPairedPeripheralUUIDKey)
    }

    private func clearPairedPeripheral() {
        UserDefaults.standard.removeObject(forKey: kPairedPeripheralUUIDKey)
    }

    private func resetConnectionState() {
        connectedPeripheral = nil
        gpsWriteChar = nil
        timezoneReadChar = nil
        unlockGPSChar = nil
        lockGPSChar = nil
        timeSyncChar = nil
        locationEnabledChar = nil
        setupPhase = .idle
        connectedDeviceName = nil
        isConnected = false
        isCameraOn = false
        isTransmitting = false
        bleState = .poweredOn
    }

    /// 開始 GPS 啟用序列：讀取 dd21 → unlock → lock → time sync
    private func beginSetupSequence(_ peripheral: CBPeripheral) {
        if let char = timezoneReadChar {
            setupPhase = .readingTimezone
            peripheral.readValue(for: char)
        } else {
            // 無 dd21，預設支援 DST，直接 unlock
            supportsDST = true
            beginUnlockGPS(peripheral)
        }
    }

    private func beginUnlockGPS(_ peripheral: CBPeripheral) {
        if let char = unlockGPSChar {
            setupPhase = .unlockingGPS
            peripheral.writeValue(Data([0x01]), for: char, type: .withResponse)
        } else {
            // 無 dd30，跳過 unlock/lock 直接就緒
            completeSetup()
        }
    }

    private func beginLockGPS(_ peripheral: CBPeripheral) {
        if let char = lockGPSChar {
            setupPhase = .lockingGPS
            peripheral.writeValue(Data([0x01]), for: char, type: .withResponse)
        } else {
            beginTimeSync(peripheral)
        }
    }

    private func beginTimeSync(_ peripheral: CBPeripheral) {
        if let char = timeSyncChar {
            setupPhase = .syncingTime
            let packet = GPSPacketEncoder.encodeTimeSync()
            peripheral.writeValue(packet, for: char, type: .withResponse)
        } else {
            completeSetup()
        }
    }

    private func completeSetup() {
        setupPhase = .ready
        isCameraOn = true
        isTransmitting = true
        lastError = nil

        let name = connectedDeviceName ?? "Sony 相機"
        onConnect?(name)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bleState = .poweredOn
            attemptAutoReconnect()
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

    /// State Restoration：App 被系統終止後重新啟動時呼叫
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let peripheral = peripherals.first {
            connectedPeripheral = peripheral
            peripheral.delegate = self
            connectedDeviceName = peripheral.name ?? "Sony 相機"
            if peripheral.state == .connected {
                isConnected = true
                bleState = .connected
                setupPhase = .discoveringServices
                peripheral.discoverServices(nil)
            }
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
        connectedDeviceName = connectedDeviceName ?? peripheral.name ?? "Sony 相機"

        // 開始 service discovery（用 nil 發現所有 service）
        setupPhase = .discoveringServices
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
        let wasConnected = isConnected
        let deviceName = connectedDeviceName ?? "Sony 相機"
        resetConnectionState()
        bleState = .disconnected

        if wasConnected {
            onDisconnect?(deviceName)
        }

        if error != nil {
            lastError = "連線中斷"
        }

        // 自動重連
        if autoConnectEnabled,
           UserDefaults.standard.string(forKey: kPairedPeripheralUUIDKey) != nil {
            bleState = .connecting
            connectedDeviceName = peripheral.name ?? "Sony 相機"
            connectPeripheral(peripheral)
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(
                GATTConstants.allCharacteristicUUIDs,
                for: service
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }

        for char in characteristics {
            switch char.uuid {
            case GATTConstants.gpsWriteUUID:
                gpsWriteChar = char
            case GATTConstants.timezoneReadUUID:
                timezoneReadChar = char
            case GATTConstants.unlockGPSUUID:
                unlockGPSChar = char
            case GATTConstants.lockGPSUUID:
                lockGPSChar = char
            case GATTConstants.timeSyncUUID:
                timeSyncChar = char
            case GATTConstants.locationEnabledUUID:
                locationEnabledChar = char
            default:
                break
            }
        }

        // 當所有 service 的 characteristic 都已搜尋完畢後，開始 setup 序列
        // （只在 discoveringServices 階段且找到至少 gpsWriteChar 時觸發）
        if setupPhase == .discoveringServices && gpsWriteChar != nil {
            beginSetupSequence(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        // dd21: 時區/DST 支援偵測
        if characteristic.uuid == GATTConstants.timezoneReadUUID,
           setupPhase == .readingTimezone {
            if let data = characteristic.value, data.count >= 5 {
                supportsDST = (data[4] & 0x02) != 0
            } else {
                supportsDST = true  // 預設支援
            }
            beginUnlockGPS(peripheral)
            return
        }

        // dd01: 位置啟用狀態通知（log only）
        if characteristic.uuid == GATTConstants.locationEnabledUUID {
            // 相機端通知，暫不需要處理
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        // Setup 階段寫入
        switch (setupPhase, characteristic.uuid) {
        case (.unlockingGPS, GATTConstants.unlockGPSUUID):
            if let error {
                lastError = "GPS Unlock 失敗：\(error.localizedDescription)"
            } else {
                beginLockGPS(peripheral)
            }
            return

        case (.lockingGPS, GATTConstants.lockGPSUUID):
            if let error {
                lastError = "GPS Lock 失敗：\(error.localizedDescription)"
            } else {
                beginTimeSync(peripheral)
            }
            return

        case (.syncingTime, GATTConstants.timeSyncUUID):
            if error != nil {
                // 時間同步失敗不是致命錯誤，繼續
            }
            completeSetup()
            return

        default:
            break
        }

        // GPS 封包傳送結果（dd11）
        if characteristic.uuid == GATTConstants.gpsWriteUUID {
            if let error {
                packetsError += 1
                lastError = "傳送失敗：\(error.localizedDescription)"
            } else {
                packetsSent += 1
                lastError = nil
            }
        }
    }
}
