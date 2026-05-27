# PurrType

PurrType 是一個 macOS 繁體中文輸入法，主打穩定速成、倉頡、拼音同英文混打。所有核心輸入處理都喺本機完成，不需要雲端服務。

## 功能重點

- 一個 macOS input source：`PurrType`。
- 四種輸入模式：`Sucheng`、`New Sucheng`、`Cangjie`、`Pinyin`。
- 傳統速成候選位置穩定，適合保留打字肌肉記憶。
- 新速成可選擇開啟本機學習、關聯候選同短語候選。
- URL、email、檔案路徑、code-like token、長英文單字同臨時 Shift 英文會盡量保留原文。
- 英文 spelling suggestions 使用 macOS 本機 spell checker 顯示候選，不會自動更正或上傳文字。
- 快速短語可用 `;` 開頭短碼輸入常用文字，例如 `;email`。
- 基本備份 / 還原會匯出或還原本機快速短語資料。
- 支援候選翻頁、5 / 9 個候選顯示、數字選字、commit 原文同取消 composition。
- 內置 Preferences，可調整模式、快捷鍵、候選數量、私隱控制同重設學習資料。
- 本機優先：候選、排序、學習同關聯候選不依賴雲端服務。

## 輸入模式

- `Sucheng`: 傳統速成，候選排位固定。
- `New Sucheng`: 新速成，可選擇使用本機學習同關聯候選。
- `Cangjie`: 倉頡輸入，適合繁體中文打字。
- `Pinyin`: 拼音輸入，輸出繁體中文候選。

英文不是獨立模式，而是自動處理。PurrType 遇到 URL、email、路徑、程式碼片段或較長英文時，會保留原文，避免強行轉成中文候選。

## 下載與安裝

直接下載 DMG：

[Download PurrType 0.1.2 DMG](https://github.com/355070xx/PurrType/releases/download/v0.1.2/PurrType-0.1.2.dmg)

不要下載 GitHub 自動產生的 `Source code` zip/tar.gz；那是原始碼，不是安裝檔。

如見到 macOS 顯示 `"Install PurrType.pkg" Not Opened` 或 `Apple could not verify...`，請跟
[圖文安裝教學](docs/INSTALL_GUIDE.md) 做，不要按 `Move to Bin`。

安裝：

1. 按上面連結下載 `PurrType-0.1.2.dmg`，然後用 Finder 打開。
2. Double-click `Install PurrType.pkg`.
3. 完成 macOS Installer 流程。
4. 如果 System Settings 已經開住，先 quit 再開返。
5. 打開 `System Settings > Keyboard > Text Input > Edit...`。
6. 加入 `PurrType`。
7. 如果仍然見不到 `PurrType`，log out 再 log in，然後再檢查 Text Input。

macOS 安裝期間可能會要求 administrator password。

更新：

1. 下載新版本 DMG，然後用 Finder 打開。
2. Double-click `Install PurrType.pkg` 直接安裝。
3. 完成 macOS Installer 流程後即可使用新版本。

更新時不需要先 uninstall；除非安裝後出現問題，否則不用每次移除再重新安裝。

移除：

1. 打開同一個 DMG。
2. Double-click `Uninstall PurrType.pkg`.
3. 完成 macOS Installer 流程。

Uninstaller 只會移除 PurrType app bundles 同 package receipts，並保留本機
PurrType preferences 同 New Sucheng learning data。

## 私隱

PurrType 採用本機處理、少量儲存、可清除嘅設計：

- 候選查詢同排序都喺 Mac 上完成。
- New Sucheng learning 預設關閉。
- Sucheng 不使用用戶學習，候選排位保持固定。
- 持久化 learning 只保存 salted hashes 同分數，不保存可讀短語。
- 快速短語會儲存在本機 `~/Library/Application Support/PurrType/quick-phrases.json`，可由用戶匯出、匯入、備份或還原。
- session-only phrase learning 會喺 engine 重開後清除。
- 似敏感資料嘅文字會被拒絕學習。
- `Privacy Lock` 可即時暫停 learning 同清走 rolling context。

完整內容見 [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md)。

## 更多資料

- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Input behavior](docs/INPUT_BEHAVIOR.md)
- [Privacy policy](docs/PRIVACY_POLICY.md)
- [Changelog](docs/CHANGELOG.md)

## License And Credits

PurrType 使用 MIT License，詳情見 [LICENSE](LICENSE)。

PurrType 整合咗部分開源及開放資料資源，相關 credits 同授權資料見 [Credits](docs/CREDITS.md) 及 [License audit](docs/LICENSE_AUDIT.md)。
