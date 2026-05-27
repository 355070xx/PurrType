# 輸入行為

## 設計原則

- 用戶應可以長時間留在同一個 input source 內打中文同英文。
- 自動判斷必須可預期，並且有 regression tests。
- 中文候選不應阻礙常見英文、URL、email、程式碼、file path 輸入。
- 所有 composition 都應可以用 Escape 取消。
- Backspace 行為要符合用戶對 macOS 文字輸入的直覺。
- `Sucheng` 固定候選位置不可被 user learning 改動。
- `New Sucheng` learning 必須 opt in，可暫停，可 reset，不保存 plaintext learned phrase。

## 基本按鍵

| 按鍵 | Idle | Composing | CandidateVisible |
| --- | --- | --- | --- |
| Letter | 開始輸入 | 追加輸入碼 | 追加或更新輸入碼 |
| Space | 輸出空格 | 多頁候選時翻下一頁；單頁候選時選首候選；無候選時輸出空格 | 多頁候選時翻下一頁；單頁候選時選首候選 |
| Tab / Right Arrow / PageDown | 無動作或交回 app | 多頁候選時翻下一頁 | 多頁候選時翻下一頁 |
| Left Arrow / Shift+Tab / PageUp | 無動作或交回 app | 多頁候選時翻上一頁 | 多頁候選時翻上一頁 |
| Enter | 換行或 commit | commit 原始輸入 | commit 原始輸入 |
| Backspace | 刪除前字 | 刪除輸入碼 | 刪除輸入碼或返回 composing |
| Escape | 無動作 | 取消 composition | 關閉候選並取消 composition |
| Number | 輸出數字 | 按目前每頁設定用數字選中文候選；`0` commit 原英文字母 | 按目前每頁設定用數字選中文候選；`0` commit 原英文字母 |

## 中文候選

當 composing buffer 命中中文候選時：

1. 顯示候選字列表。
2. 預設候選排序由 engine source score、reviewed guards 和 mode-specific ranking 決定。
3. 每頁顯示 5 或 9 個中文候選，並在候選文字前顯示相應數字；如 buffer 可當英文原文，列表另顯示 `0 <buffer>`。
4. 多於一頁時，候選窗顯示 `1/4` 形式的頁數。
5. 用戶選擇候選後清空 composition buffer，commit text 到目前 app。

本機 learning 只在 `New Sucheng` 生效。未學習的候選仍然保留 Quick Classic / verified guard 的固定排序。`Sucheng` 不讀取用戶 learning，所以固定位置不會因個人使用習慣改變。

PurrType input menu 會顯示 current mode、模式切換、候選翻頁按鍵、本機 learning 狀態、Enable New Sucheng Learning、Privacy Lock、Reset New Sucheng Learning、以及 `PurrType Preferences...`。`Ctrl+Shift+,` 會開啟或帶返 Preferences window 到前面；Preferences helper window 開住時亦會出現在 Cmd+Tab。Preferences helper active 時，`Cmd+,` 會顯示 Preferences window、`Cmd+W` 關閉 window、`Cmd+Q` 離開 helper。Preferences window 可切換模式、開關 learning、開關 Privacy Lock、開關 `0` 原文英文候選、開關 Space 翻頁、設定每頁候選字數、reset learning。Learning 狀態會標示 `Disabled`、`Enabled · Local Ranking` 或 `Paused by Privacy Lock`。

## Shortcuts

預設 shortcut：

- `Ctrl+Shift+1`: `Sucheng`
- `Ctrl+Shift+2`: `New Sucheng`
- `Ctrl+Shift+3`: `Cangjie`
- `Ctrl+Shift+4`: `Pinyin`
- `Ctrl+Shift+,`: `PurrType Preferences`
- idle 狀態連按兩次 backtick: toggle `Privacy Lock`

Mode shortcuts 可在 Preferences 自訂為 `Ctrl+Shift+1` 至 `Ctrl+Shift+9` 或 `None`。同一個 shortcut 只會保留在一個 mode；如果用戶將某個 shortcut 指派給另一個 mode，原先佔用該 shortcut 的 mode 會自動變成 `None`。

Privacy Lock shortcut 可在 Preferences 改為 double backtick、`Ctrl+Shift+\`` 或 `None`。Double backtick 只在無 active composition、raw English token 或 association candidates 時觸發；第一下 backtick 仍然照舊顯示標點候選，第二下在短時間窗內會關閉候選並切換 Privacy Lock。

## 英文 Pass-Through

以下情況應傾向英文：

- buffer 看似 URL，例如 `https://`、`www.`。
- buffer 看似 email，例如包含 `@` 且左右為英數字。
- buffer 看似 file path，例如 `/Users/`、`~/`、`./`。
- buffer 看似 code token，例如 `camelCase`、`snake_case`、`foo.bar`。
- `Sucheng` 兩碼內保留中文候選；三碼起如果沒有 exact Sucheng candidate，會轉為 raw English composition。
- New Sucheng 會保護已知 phrase seed / learned phrase code，例如 `hionaomjoo` 和 `lykjnohei`，但常見英文或較長英文形態如 `setting` 會轉為 raw English composition。
- New Sucheng 內常見短英文如 `new`、`app`、`use`、`mac` 會優先當 raw English，避免 generated phrase 把短英文硬砌成中文候選。
- New Sucheng 對常見英文 token 會 suppress generated phrase candidates；learned phrase 或明確 seed phrase 仍然優先保護。
- 沒有任何中文 engine 回傳候選時，會保留 raw English composition 直到 Space、Enter、Escape 或 Backspace 清空。
- raw English composition 內可繼續輸入 printable ASCII punctuation/symbols，避免 email、URL、path、code token 或英文句子中途彈出中文符號候選。
- 有中文候選但用戶其實想輸入原英文字母時，候選列表會提供 `0 <typed text>`；按 `0` 直接提交原文，不改動中文候選位置。
- raw English composition 用 Backspace 刪到空字串後，必須退出 raw English 狀態，下一個輸入重新按當前 engine 判斷。

英文 pass-through 不等於永久切換英文模式。完成該 token 後，輸入法應回到正常偵測。

## Shift 大楷英文

需要提供明確方式讓用戶輸入大楷英文：

- 按住 Shift 輸入字母會直接輸入大楷英文，不顯示中文候選。
- Shift 進入 raw English 後，數字與常見 token 字元會跟隨同一個英文 composition，不會突然彈出中文候選。
- 短英文或單字母撞中速成/倉頡碼時，可按 `0` commit 原文；其他數字鍵仍然只負責中文候選。
- 不提供獨立 English menu mode；中英混打以 automatic raw English pass-through 處理。
- Shift 大楷英文狀態下，中文候選不應彈出。
- 按 Escape 或完成 token 後返回原模式。

## 倉頡

預期行為：

- 支援完整倉頡碼。
- 支援候選字。
- 支援標點輸入。
- 標點與符號候選跟 IBus Cangjie5 table；逗號、句號、斜線、分號、引號、括號、backslash、backtick、dash、equals、角括號、問號、冒號、花括號、pipe、tilde 及 shifted number-row symbols 都會先保留半形原字，再提供全形/中文符號候選。
- 如果標點候選開住而用戶繼續打字，非選號 key 會先 commit 第 1 個半形候選再繼續處理新 key；按 `2` 至 `9` 仍然會明確選擇全形或中文符號。
- 使用 IBus Cangjie5 倉頡碼表作主要候選來源。
- 使用 Rime Cangjie base / extended dictionaries 作 fallback。
- 使用 DATA.GOV.HK HKSCS JSON 作低優先級香港字 overlay；只補缺字，不提升到既有候選之前。

待定：

- 容錯碼。
- 更多罕用字排序審核。
- 與速成共用候選排序的規則。

## 速成

預期行為：

- 支援首尾碼輸入。
- 候選數量可能較多，候選 UI 要支援快速翻頁。
- `Sucheng` 使用 bundled `IBusTableChinese/quick-classic.txt` 作主要候選來源；公開比較指出 IBus/SCIM/GCIN Quick Classic 與 legacy 速成候選位置相同或高度接近。
- `Sucheng` 會由 HKSCS 倉頡碼 derive 首尾碼補香港字，例如 official Cangjie `ROYV` 會補成 Sucheng `rv`；overlay 候選排在既有 Quick Classic 候選之後。
- 對已確認的 legacy 高影響碼位，用 `sucheng_order_guards.tsv` 作小型可審核排序 guard；例如 `hi` / `竹戈` 的 `我` 第 7 位、`得` 第二頁第 7 位、`等` 第三頁第 1 位。
- `Sucheng` 保持固定候選位置，避免破壞 legacy 使用者的肌肉記憶。
- `Sucheng` 的 populated alphabetic 一鍵/兩鍵碼 first page 由 `sucheng_first_pages.tsv` golden snapshot 鎖住。
- `New Sucheng` 才把用戶選過的既有同碼候選在本機升前；候選及關聯字 ranking 以 salted hash + score 持久化，檔案不保存可讀中文字詞。
- `New Sucheng` 支援 seed-based 長碼流 phrase candidates，例如 `hionaomjoo` 可出 `我們是一家人`。
- `New Sucheng` 會從 `association_phrases.tsv` 反查速成碼並自動建立 phrase candidates，例如 `lykjnohei` 可出 `中文輸入法`。
- `New Sucheng` 用 association-aware beam search 產生 phrase candidates，例如 `hionao` 可出 `我們是`，並降低嘈雜一字碼斷句的排序。
- `New Sucheng` 會記錄用戶選過的 generated phrase，下一次同一長碼會升前。
- `New Sucheng` 會記錄用戶實際 commit 過的 phrase suffix，最多八個中文字；如知道實際輸入碼，會用該碼學習，否則以 preferred 速成碼反查作 fallback。
- `Enable New Sucheng Learning` 預設關閉；關閉時 New Sucheng 不套用本機 learning，static seed、generated phrase、Sucheng 排位不受影響。
- learning 即使開啟，raw English、數字、符號、混合 token，以及包含密碼、銀行、戶口、證件、電話、地址、私鑰、錢包、驗證碼等敏感詞的文字都不得學習。
- `Privacy Lock` 開啟時會暫停 New Sucheng learning、清除目前 rolling context，並停止顯示 New Sucheng 的 learning-ranked commit 後關聯候選；Sucheng、Cangjie、Pinyin 的固定關聯詞庫照常顯示。關閉後會按原本 learning preference 恢復，不會覆寫用戶的 learning 開關。
- 既有候選及關聯字 ranking 會寫入 `~/Library/Application Support/PurrType/learning-rankings.json`，內容只含 salt、hash、score。自訂 committed phrase 只保存在目前 session 記憶體，不寫入檔案。
- `resources/association_phrases.tsv` 提供 hand-reviewed Sucheng / New Sucheng / Cangjie / Pinyin 共用的 commit 後關聯字 seed；Sucheng、Cangjie、Pinyin 不會因用戶選字而改排序，New Sucheng 才會學習。
- `resources/association_generated.tsv` 由 `make update-association-seeds` 從本機 seed、McBopomofo associated phrases、corpus、open-table/Rime 資料生成；build time 轉成 `resources/association_generated.index` 給 runtime 查 key。它用來補足四個中文模式的低優先級關連詞；hand-reviewed seed 先載入，所以固定關連詞頭位不會被 generated data 搶走。
- `quick-classic.txt`、`cangjie5.txt`、Rime Cangjie、Rime Pinyin 在 build time 轉成 `resources/CandidateTables/*.index`。Runtime 只 lazy-open read-only index，不再 parse 大型 YAML/text 字庫；Sucheng golden first-page snapshot 仍鎖住 Quick Classic 非負權重候選。
- 關連詞 lookup 先試完整已 commit 詞，再 fallback 到最後一字；例如四個中文模式 commit `你` 後可推薦 `好`，`可以` 可直接推薦 `用`，`輸` 可推薦 `入` / `入法`。

待定：

- 是否加入批量 ranking regression，比較更多常用碼位的第一頁排序。
- 是否加入更多可自訂快捷鍵。
- `New Sucheng` 是否擴充更完整的 phrase corpus、語境排序和 learning reset UI。

## 拼音

預期行為：

- 支援無聲調拼音。
- 支援常見 exact pinyin syllable / phrase lookup。
- 支援繁體輸出。
- 使用 build-time `resources/pinyin_seed.tsv` 保護常用排序。
- 使用 build-time `resources/pinyin_phrases.tsv` 補常用繁中 phrase。
- 使用 Rime Luna Pinyin dictionary 補足完整 open dictionary coverage。
- 組字時 Up / Down 可移動目前高亮候選，Space commit 高亮候選；不改候選排序。
- runtime 只讀 compiled `resources/CandidateTables/pinyin.index`，不依賴 raw TSV/YAML。
- 英文 word 和拼音 syllable 衝突時，候選 UI 應清楚但不阻塞英文輸入。

待定：

- 雙拼是否納入。
- 粵拼是否另列 engine。
- fuzzy pinyin 是否值得加入。

## English Spelling Suggestions

呢個功能屬於本機候選提示，不係獨立輸入模式。它可以在 raw English path 顯示，也可以混入一般中文候選頁，令英文撞中中文碼時不用等到 raw English mode 先見到提示。設計界線：

- spelling suggestions 只顯示為候選，不做 autocorrect。
- typed word 原文必須一直可以 commit。
- Space、Enter、punctuation、separator 不應自動替換 typed word。
- mixed candidate page 仍保留中文主候選優先；spelling suggestions 只佔第一頁末段少量位置。

## Quick Phrases

快速短語係本機自訂短碼。設計界線：

- 短碼必須以 `;` 開頭，例如 `;email`。
- `;` 在 idle 時仍然先顯示標點候選；如果下一個字元係英文字母、數字、`_` 或 `-`，PurrType 會將組字轉成快速短語短碼。
- 用戶儲存 `;email` 後，輸入完整 `;email` 會顯示對應 replacement 候選；沒有儲存的短碼只會保持 raw English composition，不會靠預設字表硬估。
- replacement 只接受單行文字，避免候選窗顯示多行內容或破壞 layout。
- 快速短語儲存在 `~/Library/Application Support/PurrType/quick-phrases.json`。
- Preferences 的 TXT import/export 使用 `;trigger<TAB>replacement`，方便用戶用普通文字編輯器修改。
- Basic backup/restore 只處理本機快速短語資料，不包含其他設定或未知 payload。
- suggestion provider 使用 macOS `NSSpellChecker` documented API。
- suggestion provider 不應對 URL、email、path、code-like token 出提示。
- suggestion lookup 對同一 token 會 cache，避免每個 keypress 重複查同一字。
- 若 dictionary 載入失敗，應降級成現有 raw English pass-through。

可測試案例：

- `speling` 顯示 `spelling` suggestion，但 `speling` 仍可原文 commit。
- 按 Space 不會自動將 `speling` 改成 `spelling`。
- 當同一 buffer 有中文候選和 spelling suggestion，第一個中文候選仍排先，suggestion 只用數字選取。
- `https://speling.example`、`foo_bar`、`./speling` 不顯示 spelling suggestion。
- Preferences 關閉後完全不顯示 spelling suggestion。

## 候選 UI

候選項目應包含：

- 候選字、詞、原文英文或 spelling suggestion。
- 選字 key `1` 至 `9`，以及可選 `0` 原文英文候選。

候選 UI 應避免：

- 覆蓋正在輸入的位置。
- 每次按鍵大幅跳動。
- 顯示過多 debug metadata。

## 可測試案例

第一批測試應覆蓋：

- 倉頡單字輸入。
- 速成多候選選字。
- 拼音輸入繁體候選。
- 無中文候選時英文直接輸入。
- URL 不觸發中文候選。
- email 不觸發中文候選。
- Backspace 更新候選。
- Escape 取消 composition。
- 傳統 Sucheng 選字後仍保持固定位置。
- New Sucheng 選字後排序更新。
- New Sucheng 選字後重開 engine 仍保留排序。
- New Sucheng 用戶選過的關聯字會排在 seed 關聯字之前。
- New Sucheng 長碼流 `hionaomjoo` 出現 `我們是一家人` phrase candidate。
- New Sucheng 從 association corpus 生成 `lykjnohei` -> `中文輸入法`。
- New Sucheng 擴充 corpus 生成 `onaatvr` -> `今日開始`。
- New Sucheng generated phrase beam 會把 `hionao` 排成 `我們是`。
- New Sucheng generated phrase 如本身是引擎可產生的候選，選字後會以 hashed ranking 保留排序；自訂 committed phrase 重開後回復底表。
- Sucheng / New Sucheng / Cangjie / Pinyin 都會從 association phrase seed 顯示 `候 -> 選`、`排 -> 位`，亦會從 generated association seed 顯示如 `輸 -> 入法` 的多字 suffix。
- `Ctrl+Shift+1/2/3/4` 模式切換、`Ctrl+Shift+,` preference shortcut、候選翻頁、`0` 原文英文候選、Shift 大楷英文都有 `PurrTypeInputBehaviorTests` regression 保護。
- `docs/typing/one_hour_typing_corpus.md` 會由 `PurrTypeTypingSimulationTests` 重複 replay 到一小時等量 keystrokes，並逐字比對輸出。測試亦覆蓋 Cangjie replay、New Sucheng custom phrase session replay、`0` 原文英文候選開關、以及 Space 翻頁開關，防止長時間中英混打、候選翻頁或選字流程出現 silent regression。
- `make audit-full-bible` 會 replay `docs/typing/full_bible_typing_corpus.md` 全本 CUV Traditional corpus，檢查每個 CJK 字都有 Sucheng reverse code、候選存在、候選頁穩定、以及 `1` 至 `9` label 正確，報告寫入 `build/full_bible_typing_audit.md`。
