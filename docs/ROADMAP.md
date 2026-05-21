# 路線圖

## Product Direction

PurrType 先做好現有輸入法，而唔擴散到更多輸入模式。`Sucheng`、`New Sucheng`、`Cangjie`、`Pinyin`、English pass-through 同本機 spelling suggestions 都應保持低延遲、可測試、可關閉。

英文 spelling suggestions 的原則：

- 只提示，不自動改字。
- typed word 必須可以原樣 commit。
- 不在 Space、Enter 或 punctuation 時偷偷替換文字。
- 不依賴雲端服務。
- 必須可關閉，並且唔干擾 URL、email、file path、code-like token。

## Phase 0: Foundation

目標：

- 建立 InputMethodKit app shell。
- 定義產品範圍、資料來源、license 和 privacy model。
- 建立 build、test、package、release artifact 基礎流程。

完成標準：

- README、產品規格、架構、輸入行為文檔存在。
- 可在本機 build input method bundle。
- 可安裝到 macOS Input Methods 目錄作手動測試。

## Phase 1: Core Input Method Shell

目標：

- 接收 key event。
- 管理 composition buffer。
- 顯示 candidate panel。
- commit text。
- 支援 preferences 入口。

完成標準：

- 在 TextEdit、Safari、Notes、Terminal 做基本輸入測試。
- Escape、Backspace、Enter、Space 行為穩定。
- 不影響常見 macOS keyboard shortcut。

## Phase 2: Existing Chinese Engines

目標：

- 完整化 `Sucheng` 固定候選位置。
- 完整化 `New Sucheng` phrase candidates、關聯候選和 opt-in local learning。
- 完整化 `Cangjie` 候選覆蓋。
- 完整化 `Pinyin` open dictionary 覆蓋和常用字排序。
- 定義共用 candidate model 和 regression tests。

完成標準：

- 常用速成、倉頡、拼音輸入可用。
- Sucheng first page 有 golden snapshot 保護。
- New Sucheng learning 不影響 Sucheng 固定排位。
- Pinyin 有完整 open dictionary fallback，seed table 只負責常用排序。
- Engine cold start 只開 Classic Sucheng 的 Quick candidate index；Cangjie、Pinyin、New Sucheng phrase data 由首次使用 lazy-load。Quick Classic、Cangjie5、Rime Cangjie、Rime Pinyin 和 generated association 已改為 build-time read-only index，runtime 不再 parse 大型 YAML/text/TSV，並有 startup benchmark 報告保護。
- 測試覆蓋單字、多候選、無候選、關聯候選、長碼 phrase、candidate paging。

## Phase 3: Mixed Chinese / English Input

目標：

- 保持 automatic raw English pass-through。
- URL、email、path、code-like token 不被中文候選打斷。
- Shift 大楷英文穩定。
- 短英文撞中中文候選時提供 `0` raw-English candidate。

完成標準：

- 用戶可以長時間留在同一 input source 內打中英文。
- 常見網址、email、command、file path 不被中文候選阻塞。
- `0` raw-English candidate、Space paging、candidate page size preference 有 regression tests。

## Phase 4: Privacy, Learning, And Recovery

目標：

- New Sucheng learning 預設關閉。
- 本機 ranking file 只保存 salt、hash、score。
- Privacy Lock 暫停 New Sucheng learning、清 rolling context、只隱藏 New Sucheng learning-ranked post-commit association；固定 Sucheng/Cangjie/Pinyin association 不受影響。
- Terminal-style secure event input 時 bypass composition/candidate UI，並切去 ASCII / English input source；一般 editor 不應因其他 app 的 global secure input 被即時切走。
- Reset learning 可清除持久化 ranking 和 in-memory learning state。

完成標準：

- 測試檢查 learning file 不保存 plaintext phrase。
- `Sucheng` 永遠不套用 user learning。
- `New Sucheng` 可 opt-in 套用 hashed local ranking。
- 重開 engine 後既有候選 ranking 保留，自訂 committed phrase 回復底表。

## Phase 5: Packaging And Release

目標：

- 可重現 package / DMG artifact。
- package payload smoke test。
- input-source metadata inspection。
- 可選 Developer ID signing、notarization、stapling。
- release provenance 和 checksums。

完成標準：

- 一般 macOS 用戶可用 `.pkg` 安裝。
- 安裝、更新、移除流程有文檔。
- `make release-preflight` 覆蓋 tests、audits、package smoke 和 DMG metadata。
- signed release path 在 credential 缺失時 fail early，不產生半成品。

## Phase 6: English Spelling Suggestions

目標：

- 使用 macOS `NSSpellChecker` 加入本機英文 spelling suggestion engine。
- 將 suggestion 當候選提示，不當 autocorrect。
- 保留 typed word 原文 commit 路徑。
- 避免干擾 raw English pass-through、URL、email、path、code-like token。
- 不 bundle 或抽取 Apple dictionary 資料。

完成標準：

- suggestions 可在 Preferences 關閉。
- 沒有 suggestion 時完全不影響現有英文 pass-through。
- Space / Enter / punctuation 不會自動替換 typed word。
- 測試覆蓋 misspelling suggestion、原文 commit、URL/email/path/code suppression、disable preference。
- repeated suggestion lookup 對同一 token 會 cache；provider 失敗時降級 raw English pass-through。
- Advanced Dictionary Manager、per-app policy、technical/legal/medical/developer word packs 留作後續 slice。


## Backlog

- 粵拼 engine。
- 雙拼。
- 自訂碼表匯入。
- 詞庫匯入工具。
- 多語言 UI。
- 候選 UI 主題。
- CLI debug 工具。
