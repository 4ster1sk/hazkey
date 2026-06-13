# AI Workflows

## 基本方針

- まず `AGENT.md` と `docs/ai-architecture.md` を読む。
- 次に、変更が `protocol` 起点か、UI 起点か、変換ロジック起点かを切り分ける。
- protobuf を変える場合は、片側だけ直す作業をしない。

## タスク別の進め方

### キー入力バグ

1. `fcitx5-hazkey/src/hazkey_state.cpp` でどのモードのキー処理かを確認
2. 送っている protobuf を `hazkey_server_connector.cpp` で確認
3. 実際の変換は `hazkey-server/state.swift` と `keymap.swift` で追う

### 候補や変換品質の変更

1. `hazkey-server/state.swift#getCandidates`
2. `hazkey-server/config.swift#genBaseConvertRequestOptions`
3. 必要なら `hazkey-settings` の候補数 UI

### 設定項目追加

1. `protocol/config.proto`
2. `hazkey-server/config.swift`
3. `hazkey-settings/mainwindow.ui`
4. 対応タブの controller
5. 必要なら fcitx5 側の設定ロード

### Zenzai 関連

1. `hazkey-settings/controllers/ai_tab_controller.cpp`
2. `hazkey-server/config.swift`
3. `hazkey-server/CMakeLists.txt`
4. `hazkey-server/hazkey-server.sh.in`

## 推奨コマンド

### 依存込み clone

```sh
git clone --recursive https://github.com/7ka-Hiira/hazkey.git
```

### 全体ビルド

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### モジュール単位ビルド

```sh
cmake -S fcitx5-hazkey -B build/fcitx5-hazkey -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/fcitx5-hazkey

cmake -S hazkey-server -B build/hazkey-server -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/hazkey-server

cmake -S hazkey-settings -B build/hazkey-settings -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/hazkey-settings
```

### ルートインストール例

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
cmake --install build
```

## 検証レベル

### 最小

- 変更モジュールだけビルド
- `git diff --check`

### 推奨

- 変更モジュールの隣接モジュールもビルド
- protobuf を変えたら 3 コンポーネントを確認

### 手動確認候補

- fcitx5 入力開始時に preedit が出るか
- `Tab` / `Space` / `Enter` で候補遷移が壊れていないか
- 設定保存後に再読込して値が保持されるか
- Zenzai モデル有無で AI タブの警告が切り替わるか

## デバッグ時の観点

### ソケットがつながらない

- クライアント側:
  - `fcitx5-hazkey/src/hazkey_server_connector.cpp`
  - `hazkey-settings/serverconnector.cpp`
- サーバー側:
  - `hazkey-server/Sources/hazkey-server/server.swift`
  - `hazkey-server/Sources/hazkey-server/socketManager.swift`
  - `hazkey-server/Sources/hazkey-server/processManager.swift`

確認ポイント:

- `XDG_RUNTIME_DIR`
- lock file の残骸
- サーバーの単一接続前提

### 設定が保存されない

- `hazkey-settings/mainwindow.cpp`
- `hazkey-settings/controllers/*`
- `hazkey-server/config.swift`
- `~/.config/hazkey/config.json` または `XDG_CONFIG_HOME/hazkey/config.json`

### keymap / table が効かない

- `hazkey-server/config.swift#loadKeymap`
- `hazkey-server/config.swift#loadInputTable`
- `hazkey-settings/controllers/input_style_tab_controller.cpp`

## CI から読むべきこと

- `.github/workflows/build.yml` が現実のビルド手順です。
- Ubuntu 22.04 / 24.04 と arm64 を見ています。
- `hazkey-settings` だけ `mainwindow.ui` に対して Qt 互換の前処理を入れています。
- static protobuf ビルドの経路もあるため、protobuf 周りの変更は shared 前提で決め打ちしない方が安全です。

## 変更前チェックリスト

- 仕様変更なら `protocol/*.proto` を先に見たか
- 生成物ではなくソースオブトゥルースを触っているか
- サブモジュール前提のファイルを消していないか
- 設定追加なら server 保存と settings UI の両方を見たか
- ソケット関連変更で client/server の両端を見たか
