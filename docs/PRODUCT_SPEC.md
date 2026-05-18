# 產品規格

## 背景

macOS 內建中文輸入法對部分香港繁體中文用戶來講，未必貼近傳統速成、倉頡使用習慣。現有第三方方案有些長期缺乏更新，有些需要較多設定，亦未必提供理想的中英文混打體驗。

PurrType 目標係建立一個開源、可維護、重視本機私隱的 macOS 輸入法，讓用戶可以在同一個輸入法體驗內完成速成、倉頡、拼音、英文混打、候選選字、關聯候選同 New Sucheng 本機 learning。
PurrType 向 macOS 註冊一個 `PurrType` input source；速成、新速成、倉頡同拼音係 app 內部模式，由 PurrType menu、快捷鍵同 Preferences 切換。

## 目標用戶

- 習慣傳統速成或倉頡的 macOS 用戶。
- 需要繁體中文、英文頻繁混打的香港用戶。
- 想使用開源、本機處理、不依賴雲端輸入法的用戶。
- 希望輸入法行為穩定、低延遲、可自訂的進階用戶。

## 支援輸入方式

### Current Product

- `Sucheng`
- `New Sucheng`
- `Cangjie`
- `Pinyin`
- automatic raw English pass-through

### Future Product

- 英文 spelling suggestions，候選提示式，不自動更正。
- 更完整的關聯詞、phrase corpus、語境排序。
- 用戶自訂詞庫或碼表匯入工具。

### 明確不支援

- 筆劃輸入。
- 九方輸入。
- 未授權商業碼表。
- 雲端依賴式候選生成。
- automatic autocorrect。

## 核心需求

### 中文輸入

- 支援 composition buffer。
- 支援候選字列表。
- 支援數字鍵或 row click 選擇候選。
- 支援 backspace 修改已輸入碼。
- 支援 escape 取消 composition。
- 支援 Enter commit 原始輸入。
- 支援 Space 按 preference 做候選翻頁或首候選 commit。

### Sucheng

- `Sucheng` 使用固定 Quick Classic / reviewed legacy anchor 排位。
- 使用 DATA.GOV.HK HKSCS overlay 補香港常用字；overlay 候選排在既有 Quick Classic 候選之後。
- Quick Classic 候選由 build-time read-only index 提供；runtime 不應 parse bundled source text table。
- `Sucheng` 不讀取、不套用、不寫入 user learning。
- first page 排位由 golden snapshot 保護。
- 關聯候選可顯示，但用戶選擇不會改變固定候選位置。

### New Sucheng

- 以 `Sucheng` 同一套底表開始。
- learning 預設關閉，用戶要 opt in。
- 可用 salted hash + score 持久化既有候選和 association ranking。
- committed phrase learning 只保存在目前 session 記憶體。
- phrase candidates 可來自 hand-reviewed seeds、generated association corpus、association-aware beam search、session learning。
- learning 必須過濾 raw English、數字、符號、mixed token 同 sensitive terms。

### Cangjie

- 使用 IBus Cangjie5 table 作主要候選來源。
- 使用 Rime Cangjie base / extended dictionaries 作 fallback。
- 使用 DATA.GOV.HK HKSCS overlay 補香港常用字。
- 倉頡候選來源應在 build time 轉成 read-only index，並在第一次使用 Cangjie mode 時才 lazy-open。
- 保持繁體輸出和穩定候選排序。
- commit 中文候選後顯示共用關聯候選，例如 `你 -> 好`。

### Pinyin

- 使用 local seed table 保護常用排序。
- 使用 Rime Luna Pinyin dictionary 提供較完整 open dictionary 覆蓋。
- 拼音候選來源應在 build time 轉成 read-only index，並在第一次使用 Pinyin mode 時才 lazy-open。
- 支援繁體候選。
- 英文 word 和 pinyin syllable 衝突時，候選 UI 要清楚但不阻塞英文原文 commit。
- commit 中文候選後顯示共用關聯候選，例如 `你 -> 好`。

### 英文輸入

- 沒有中文候選時，應直接保留 raw English composition。
- URL、email、檔案路徑、程式碼常見 pattern 應傾向英文 pass-through。
- 短英文 token 同中文候選撞碼時，候選列表應提供 `0 <typed text>` 原文 commit。
- 英文 pass-through 不應破壞 macOS 原生快捷鍵。

### Future English Spelling Suggestions

- suggestion 只作候選提示，不自動更正。
- typed word 原文必須仍然可直接 commit。
- 不在 Space、Enter、punctuation 或 separator 自動替換。
- 不送出雲端查詢。
- suggestion lookup 應使用本機 memory index，避免 keypress hot path 同步 disk I/O。
- URL、email、path、code-like token 應 suppress suggestion。

## 私隱與資料

- 預設所有輸入處理在本機完成。
- 不上傳用戶輸入內容。
- 不記錄密碼欄位或 secure input context。
- 當 terminal-style app 觸發 macOS secure event input，輸入法應 bypass composition、候選 UI 及 learning，並切去可選的 ASCII / English input source；一般 editor 不應因其他 app 的 global secure input 被即時切走。
- 提供可見的 Privacy Lock，讓用戶可即時暫停 learning、清除 rolling context，並停止顯示敏感輸入後的關聯候選。
- 本機詞頻資料應可清除。
- 日誌不得包含完整輸入內容，除非開發者明確開啟 debug 且有遮罩策略。

## 成功標準

- 日常打字延遲低，無明顯卡頓。
- Engine cold start 不應同步載入非當前 mode 的大型 Cangjie / Pinyin / New Sucheng generated 資料；相關字庫應第一次使用該 mode 時才載入。
- package artifact 應包含 runtime `.index` resources，並排除不需要在 runtime parse 的大型 source dictionary/table files。
- 常見倉頡、速成、拼音候選準確。
- 英文混打不需要頻繁手動切換。
- Sucheng 固定候選位置不受 New Sucheng learning 影響。
- New Sucheng learning 可 opt in、可 reset、可通過 plaintext leakage tests。
- 安裝、啟用、移除流程清晰。
- 輸入法 menu 提供可見模式狀態、模式切換、候選按鍵提示和本機 learning 管理入口。
- 文檔足夠新貢獻者理解架構、資料來源、私隱模型同開發方向。
