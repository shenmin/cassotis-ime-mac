# Cassotis IME - 言泉輸入法

[English](README.md) | [簡體中文](README.zh-Hans.md) | 繁體中文

言泉輸入法的 macOS 版，以 Windows / Linux 版與 Cassotis Lexicon 為基礎。

[官網](https://www.yanquan.org/mac) · [下載安裝套件](https://github.com/shenmin/cassotis-ime-mac/releases) · [Windows](https://github.com/shenmin/cassotis-ime) · [Linux](https://github.com/shenmin/cassotis-ime-linux)

原生 macOS 拼音輸入法，採用 **InputMethodKit / AppKit 前端與 Free Pascal 獨立引擎處理程序**。共用的正式引擎對齊 Windows 1.25.0，使用 Lexicon 1.25.0 詞庫與相同的本機模型。後續更新以 Windows 版為基準。

版本 **0.1.0**（build **1**），適用於 Apple Silicon。部署目標為 macOS 14+，本輪實測環境為 M2 Pro / macOS 26.6.2；其他系統與架構的驗證範圍請見 [COMPATIBILITY.md](COMPATIBILITY.md)。

## 主要功能

- 全拼、簡拼，以及微軟／小鶴／自然碼／搜狗／紫光／拼音加加六種雙拼方案。
- 簡體與繁體詞庫、模糊拼音、分段選詞、長句排序與本機句子修正。
- 固定兩行候選視窗：第一行最多九項，始終保留 Tab 補全行，右下顯示 logo 與版本；使用者詞可點選旁邊的小紅 × 刪除。
- 原生候選視窗與設定介面，候選項橫排不換行、預設 14 點字級、八種配色選項與即時預覽；候選視窗不會搶走輸入焦點。
- 切換中英文或從其他輸入法切入言泉時，在游標旁以短暫的動畫氣泡顯示言泉 logo 與「中」或「英」，並避開附近的系統游標標誌；開始輸入後自動收起。
- 左側分類設定、字體名稱補全，以及可直接按鍵錄製的五項快捷鍵；確定選項後自動儲存，保留 macOS 系統組合鍵與安全密碼欄位的正常行為。
- 所有推論皆在本機透過 CPU ONNX Runtime 執行；安裝後不需要編譯器、Python 或網路服務。

## 安裝與試用

一般使用者下載並開啟 DMG，按兩下其中的「安装言泉输入法」，再點選「安装」。完成後點選「打开键盘设置」，在「系統設定 → 鍵盤 → 文字輸入 → 編輯 → + → 中文（簡體）」中加入「言泉输入法」，再從選單列的輸入選單選用。已加入的輸入來源可直接選用；選取時會顯示彩色言泉 logo。輸入 `nihao` 後按空白鍵，即可試打「你好」。

圖形安裝程式會顯示進度，升級時保留設定與學習紀錄，失敗時提供記錄檔與重試選項。使用時不需要終端機、編譯器、Python 或另外下載模型。檔名帶有 `-local` 的套件使用本機臨時簽章，帶有 `-signed` 的套件使用 Developer ID 簽章；這兩種測試套件均未經 Apple 公證。安裝程式也提供解除安裝功能；請先從系統設定移除輸入來源。

## 建置與安裝

開發需要 **Free Pascal 3.2.2、Xcode 命令列工具與 Python 3.11+**，不依賴 Lazarus/LCL。準備 [Cassotis Lexicon v1.25.0](https://github.com/shenmin/cassotis-lexicon/tree/v1.25.0) 的產生資產，將 `CASSOTIS_LEXICON_ROOT` 指向自己的詞庫目錄（`/path/to/...` 為佔位路徑）：

```sh
export CASSOTIS_LEXICON_ROOT="/path/to/cassotis-lexicon"
./build_all.sh
./install.sh
```

應用程式輸出至 `build/arm64/Cassotis.app`，安裝至 `~/Library/Input Methods/Cassotis.app`。從「系統設定 → 鍵盤 → 文字輸入」加入「言泉输入法」，再透過輸入選單啟用。如果系統清單尚未更新，可登出後重新登入。

預設以 Shift 切換中英文、空白鍵或數字鍵選取候選、Tab 接受補全，並以 Ctrl+Shift+F10 開啟設定。完整按鍵與資料位置請見 [CONFIGURATION.md](CONFIGURATION.md)。

`./rebuild_all.sh` 會清理建置輸出並完整重建；`./uninstall.sh` 會解除安裝目前使用者的輸入法並保留學習紀錄。建置環境、模型下載與詞庫匯入說明請見 [BUILD.md](BUILD.md)。預設建置使用本機臨時簽章，封裝與簽署方式也請見建置文件。

## 驗證與基準測試

發行驗證涵蓋核心輸入行為、模型執行、詞庫匯入、IPC、組字輸入、故障復原與設定儲存，並驗證原生文字控制項、WebKit、Chrome、Electron 和 Terminal 中的實際輸入。

完整基準測試已通過所有固定門檻。長句 Top1 / Top2 為 11,695 / 12,835，與 Windows 1.25.0 分別相差 −3 / +5；兩套短詞排序與短詞補全簽章完全對齊。長句補全在正式環境的 50 ms 預算與無補全時限下，均為 413 次命中、淨節省 952 次按鍵，與 Windows 準確率對照相差 7 次按鍵。長句查詢平均／P95 延遲為 78.984 / 151 ms，有上下文的短詞為 7.606 / 18 ms。完整評分方法、各平台對照與效能範圍請見 [BENCHMARK.md](BENCHMARK.md)。原始碼散布包含執行元件與建置工具；測試程式、桌面自動化、基準工具、語料與逐例診斷不隨原始碼散布。

## 原始碼與授權

`src/macos` 是原生前端，`src/service` / `src/ipc` 提供處理程序通訊協定，`src/engine` / `src/dictionary` 為共用的正式核心，`src/host` 負責承載本機模型。模組說明請見[架構文件](docs/ARCHITECTURE.md)。模型/schema 校驗值與詞庫輸入雜湊值分別位於 `data/runtime-assets.sha256` 和 `data/lexicon-inputs.json`，授權與來源請見 [NOTICE.md](NOTICE.md)。應用程式碼採用 GPL-3.0，詞庫採用上游聲明的 CC BY-SA 4.0。
