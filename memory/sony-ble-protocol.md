# Sony Camera BLE GPS Protocol

參考來源：[Saschl/Alpha-GPS](https://github.com/Saschl/Alpha-GPS)（Android）
本地副本：`reference/Alpha-GPS/`

## Service UUIDs

| Service | UUID |
|---------|------|
| Control (CC) | `8000CC00-CC00-FFFF-FFFF-FFFFFFFFFFFF` |
| GPS (DD) | `8000DD00-DD00-FFFF-FFFF-FFFFFFFFFFFF` |

## Characteristic UUIDs

| UUID | 名稱 | 用途 | 類型 |
|------|------|------|------|
| `0000dd11-...` | GPS Write | 寫入 GPS 封包 | Write |
| `0000dd21-...` | Timezone Read | 讀取 TZ/DST 支援旗標 | Read |
| `0000dd30-...` | Unlock GPS | 寫入 0x01 啟用 GPS | Write |
| `0000dd31-...` | Lock GPS | 寫入 0x01 鎖定 GPS | Write |
| `0000dd01-...` | Location Enabled | 位置啟用狀態 | Notify |
| `0000cc13-...` | Time Sync | 寫入 13 bytes 時間同步 | Write |

**注意**: `0000cc05-...` 不在 Alpha-GPS 協定中，不應使用。

## 連線流程

```
1. connect(peripheral)
2. discoverServices(nil)     ← 用 nil，不假設 service UUID
3. discoverCharacteristics(all)
4. readValue(dd21)           ← value[4] & 0x02 != 0 → 支援 TZ/DST
5. write 0x01 → dd30        ← Unlock GPS
6. write 0x01 → dd31        ← Lock GPS
7. write timeSync → cc13    ← 選擇性
8. GPS 就緒，開始傳送到 dd11
```

## GPS 封包格式

### 有 TZ/DST（95 bytes）

| Offset | Size | Content |
|--------|------|---------|
| 0 | 1 | `0x00` |
| 1 | 1 | `0x5D` |
| 2 | 1 | `0x08` |
| 3 | 1 | `0x02` |
| 4 | 1 | `0xFC` |
| 5 | 1 | `0x03` (DST flag) |
| 6-8 | 3 | `0x00 0x00 0x00` |
| 9-11 | 3 | `0x10 0x10 0x10` |
| 12-15 | 4 | Latitude (Int32 BE, degrees * 1e7) |
| 16-19 | 4 | Longitude (Int32 BE, degrees * 1e7) |
| 20-21 | 2 | Year (UInt16 BE, **UTC**) |
| 22 | 1 | Month (UTC) |
| 23 | 1 | Day (UTC) |
| 24 | 1 | Hour (UTC) |
| 25 | 1 | Minute (UTC) |
| 26 | 1 | Second (UTC) |
| 27-90 | 64 | Padding (zeros) |
| 91-92 | 2 | TZ offset (Int16 BE, minutes) |
| 93-94 | 2 | DST offset (Int16 BE, minutes) |

### 無 TZ/DST（91 bytes）

同上但：byte[1]=`0x59`, byte[5]=`0x00`, 無 byte[91-94]

## Time Sync 封包（13 bytes → cc13）

| Offset | Size | Content |
|--------|------|---------|
| 0 | 1 | `0x0C` |
| 1-2 | 2 | `0x00 0x00` |
| 3-4 | 2 | Year (UInt16 BE) |
| 5 | 1 | Month |
| 6 | 1 | Day |
| 7 | 1 | Hour |
| 8 | 1 | Minute |
| 9 | 1 | Second |
| 10 | 1 | DST flag (0 or 1) |
| 11 | 1 | TZ hours (signed byte) |
| 12 | 1 | TZ minutes (absolute) |

## 重要注意事項

- 日期時間**必須使用 UTC**，時區偏移以獨立欄位表達
- 所有多 byte 整數為 **Big-Endian**
- GPS 封包寫入使用 `.withResponse`
- Alpha-GPS 預設 10 秒傳送一次
- MTU 建議 158 bytes
