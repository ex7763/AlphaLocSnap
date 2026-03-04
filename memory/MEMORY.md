# AlphaLocSnap Project Memory

## 專案目標
iOS App，透過 BLE (GATT) 將 iPhone GPS 座標傳送給 Sony 相機。

## 主要架構
- `AppModel` (@Observable) 組合 LocationManager + BLEManager
- `LocationManager` (CoreLocation, @Observable)
- `BLEManager` (CoreBluetooth, @Observable)
- `GPSPacketEncoder` - 95 bytes Sony GPS 封包編碼
- `GATTConstants` - BLE UUID 常數

## Sony BLE 協議重點
詳見 [sony-ble-protocol.md](sony-ble-protocol.md)（參考 Alpha-GPS）
- 連線後需 unlock(dd30) → lock(dd31) 序列才能啟用 GPS
- 讀取 dd21 偵測 TZ/DST 支援，決定封包格式（95 or 91 bytes）
- GPS 封包 lat 在 byte[12-15]，lng 在 byte[16-19]，時間用 UTC
- `cc05` 不在協定中，已移除

## 專案設定
- Xcode 26.2 (iOS 26.2 deployment target)
- PBXFileSystemSynchronizedRootGroup（檔案自動同步）
- GENERATE_INFOPLIST_FILE = YES（在 pbxproj 加權限）
- SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor

## 檔案結構
```
AlphaLocSnap/
  AppModel.swift
  BLEManager.swift
  ContentView.swift
  GATTConstants.swift
  GPSPacketEncoder.swift
  LocationManager.swift
  AlphaLocSnapApp.swift
  Views/
    DeviceListView.swift
    StatusCardView.swift
```

## 實作狀態
✅ 核心功能 + 背景 GPS + BLE 自動重連 + 通知
✅ BLE 協定修正（參考 Alpha-GPS，修正封包格式、啟用序列）
- 需要真實 iPhone + Sony 相機驗證完整流程
