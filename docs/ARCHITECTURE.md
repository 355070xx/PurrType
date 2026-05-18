# 架構設計

## 目標

PurrType 要在 macOS 上提供低延遲、可維護、可測試的文字輸入流程。架構邊界要清楚分開 macOS integration、input session state、table/dictionary lookup、candidate ranking、local learning、preferences 和 package resources。

現有 runtime 支援 `Sucheng`、`New Sucheng`、`Cangjie`、`Pinyin` 同 automatic raw English pass-through。未來英文 spelling suggestions 應作為 optional candidate provider 加入，而唔應該改變現有英文原文 commit path。

## 高層架構

```text
Keyboard event
  -> macOS InputMethodKit frontend
  -> Input session controller
  -> Mode detector
  -> Engine router
  -> Input engine / Raw English path
  -> Candidate ranker
  -> Candidate UI / Commit text
  -> Optional local learning overlay
```

Future English spelling suggestions 只應接在 raw English candidate path 之後：

```text
Raw English token
  -> token classifier
  -> local spelling suggestion provider
  -> candidate UI
  -> user-selected suggestion or original typed word
```

呢條 future path 不得自動替換 typed word。

## 模組

### macOS Frontend

責任：

- 使用 InputMethodKit 接收 macOS text input event。
- 管理每個 client session 的 composition state。
- 顯示候選字視窗。
- commit text 到目前 app。
- 處理 activate、deactivate、preferences、secure input 等 macOS 狀態。

不應負責：

- 詞庫查詢細節。
- 候選排序策略。
- 用戶詞頻資料格式。

### Input Session Controller

責任：

- 保存當前 composing buffer。
- 保存當前候選列表和 candidate page。
- 管理輸入狀態轉換。
- 將 key event 轉成 engine request。
- 確保 Escape、Backspace、Enter、Space、candidate number key 行為一致。

### Mode Detector

責任：

- 判斷當前輸入應走中文候選、raw English composition 或系統快捷鍵。
- 偵測 URL、email、file path、code-like token。
- 處理 Shift temporary English。
- 保護已知 New Sucheng phrase codes，避免常見長碼 phrase 被當英文吞走。

Mode detector 不應作不可解釋的黑箱判斷。每個判斷都要能用規則或 regression test 描述。

### Engine Router

責任：

- 將 request 分派到 `Sucheng`、`New Sucheng`、`Cangjie` 或 `Pinyin`。
- 依照目前 mode 回傳候選。
- 保存每個 engine 的 enabled 狀態和 fallback 狀態。
- 在 engine 初始化失敗時讓其他 mode 繼續運作。

Engine router 不負責 future English spelling suggestions。spelling suggestions 應屬於 raw English candidate path，並以 preference 控制。

### Input Engine

每個中文 engine 提供一致接口：

```text
query(input, context) -> candidates
commit(candidate, context) -> committed_text
reset()
```

候選結果至少包含：

- display text
- commit text
- input code
- engine id
- base score
- source metadata

Runtime 不應 parse 大型 YAML/text/TSV 字庫。0.1.0 的資料流係 build-time indexing、runtime read-only lookup：

- Quick Classic、Cangjie5、Rime Cangjie、Rime Pinyin 在 build time 轉成 `CandidateTables/*.index`。
- Generated association rows 在 build time 轉成 `association_generated.index`。
- Runtime 只 memory-map read-only code/key index；Classic Sucheng cold path 開 Quick index，Cangjie / Pinyin 在第一次查詢相關 mode 時 lazy-open。
- Package artifact 保留 runtime 需要的 `.index`、license、HKSCS overlay 同 legal resources，排除不需要在 runtime parse 的大型 source dictionary/table files。
- `make test` 內的 startup benchmark 會檢查 Cangjie / Pinyin 不可在 cold init 時載入，並輸出 `build/engine-startup-report.md`。

### Candidate Ranker

責任：

- `FixedRanking` 管 Sucheng / Cangjie / Pinyin 的 table order、reviewed order guard、fixed association seed / generated association，輸出不可因 user learning 或 Privacy Lock 改變。
- `LearningRanking` 只服務 `New Sucheng`，把 candidate、association、phrase learning 作本機 overlay。
- `PrivacyPolicy` 只暫停 `New Sucheng` learning / rolling context；不得刪走 Sucheng、Cangjie、Pinyin 的 fixed candidates 或 fixed associations。
- 保持排序穩定，避免候選位置頻繁跳動。
- 確保 `Sucheng` 固定候選位置不受 user learning 影響。
- 不在 key event hot path 做重型 I/O。

### Persistence

責任：

- 儲存 preferences 及 New Sucheng 既有候選 ranking score。
- 使用 atomic write。
- learning ranking persistence 只保存 per-file salt、candidate/association hash、score，不保存可讀中文字詞。
- 自訂 committed phrase learning 只留在記憶體，不寫入磁碟。
- Privacy Lock 開啟時，frontend 會暫停 New Sucheng learning、清除 rolling context，並停止 New Sucheng 的 learning-ranked post-commit association UI；Sucheng、Cangjie、Pinyin 的固定 association seed 不受影響。關閉後按原本 learning preference 恢復。
- 不使用系統私密儲存、不要求額外權限。
- Sucheng 不套用用戶 learning；New Sucheng 才把 candidate、association、phrase learning 作本機 overlay。

## 狀態機

基本狀態：

- `Idle`
- `Composing`
- `CandidateVisible`
- `RawEnglish`
- `Committed`
- `Cancelled`

轉換概要：

```text
Idle + typing key -> Composing or RawEnglish
Composing + candidates found -> CandidateVisible
Composing + no candidates -> RawEnglish or direct commit
CandidateVisible + select Chinese candidate -> Committed
CandidateVisible + 0 raw-English option -> Committed
CandidateVisible + Escape -> Cancelled
CandidateVisible + Backspace -> Composing or Idle
RawEnglish + separator -> Committed
```

Future spelling suggestions 只可在 `RawEnglish` / `CandidateVisible` 之間加入 candidate rows，不可加入自動替換 transition。

## 故障模式

### Engine Unavailable

如果某個 engine 初始化失敗：

- 記錄非敏感錯誤。
- 停用該 engine。
- 其他 engine 繼續可用。
- Preferences 顯示 degraded 狀態。

### Dictionary Corrupted

如果碼表或詞庫損壞：

- 不應 crash input method process。
- 使用其他可用 source 或停用相關 engine。
- 用戶詞頻資料應保留備份或可重建。
- package smoke test 應阻止缺少 required resource 的 artifact 發佈。

### Candidate UI Unavailable

候選 UI 不能顯示時：

- composition buffer 仍應可取消。
- Enter 應可 commit 原始文字。
- 錯誤要可觀察，但不得阻塞輸入。

### Spelling Suggestion Provider Unavailable

Future spelling suggestion provider 如果初始化失敗：

- 應自動降級成現有 raw English pass-through。
- 不應阻塞中文 engine。
- 不應改變 typed word 原文 commit。

## 技術取捨

### Bundled Open Tables And Dictionaries

優點：

- 本機、可審核、可 package-smoke。
- 查詢 latency 穩定。
- 符合不依賴雲端服務的 privacy model。

缺點：

- dictionary quality 要靠 seed、guards、audit 和 regression tests 持續維護。
- package size 會比純 seed table 大。

### Custom Table Engine

優點：

- 可完全控制混打、排序、候選 UI、New Sucheng learning、資料格式。
- 容易對 Sucheng fixed-position 行為加 golden snapshot 和 guard。

缺點：

- 需要自行處理大量輸入法細節。
- 拼音分詞、英文 suggestions 和語境排序需要逐步打磨。

### Future Local English Dictionary

優點：

- 可做到 spelling suggestions 而不送雲端。
- 可用同一 candidate UI 表示「原文」同「建議拼法」。

缺點：

- 要避免干擾 raw English pass-through。
- dictionary load/index 需要在啟動或 background 完成，不能在 keypress path 同步讀檔。
