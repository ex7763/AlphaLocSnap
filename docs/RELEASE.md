# 發佈流程

## 前置準備

1. 確保程式碼已 commit 並推送到 GitHub
2. 確認所有功能測試完成

## 編譯 Release 版本

```bash
cd /Users/hpc/Project/AlphaLocSnap

# 1. 編譯 Release 版本（不含簽名）
xcodebuild -project AlphaLocSnap.xcodeproj -scheme AlphaLocSnap \
  -configuration Release \
  -destination 'generic/platform=iOS' build \
  CODE_SIGN_IDENTITY="Apple Development" \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## 建立 IPA

```bash
# 2. 建立 Payload 目錄並複製 app
mkdir -p ./Release/Payload
cp -R /Users/hpc/Library/Developer/Xcode/DerivedData/AlphaLocSnap-*/Build/Products/Release-iphoneos/AlphaLocSnap.app ./Release/Payload/

# 3. 建立 IPA
cd ./Release
zip -r AlphaLocSnap.ipa Payload
```

## 更新 AltSource

編輯 `altsource/AltSource.json`：

```json
{
  "versions": [
    {
      "version": "1.1.0",        // 版本號
      "buildVersion": "2",        // build 版本
      "date": "2026-03-05T00:00:00Z",
      "localizedDescription": "更新說明",
      "downloadURL": "https://github.com/ex7763/AlphaLocSnap/releases/download/v1.1.0/AlphaLocSnap.ipa",
      "size": 5000000
    }
  ]
}
```

## GitHub Release

```bash
# 1. 建立並推送到 tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main --tags

# 2. 建立 GitHub Release（會自動上傳 IPA）
gh release create v1.1.0 \
  --title "AlphaLocSnap v1.1.0" \
  --notes "更新說明" \
  ./Release/AlphaLocSnap.ipa
```

## AltStore / SideStore 更新

更新 `altsource/AltSource.json` 後，推送到 GitHub：

```bash
git add altsource/AltSource.json
git commit -m "Update AltSource to v1.1.0"
git push origin main
```

使用者即可在 AltStore/SideStore 中檢查更新。

## 版本號規則

- **version**: Semantic versioning，如 `1.0.0`, `1.1.0`
- **buildVersion**: 遞增數字，如 `1`, `2`, `3`
