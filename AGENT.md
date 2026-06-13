# AGENT.md

## 目的

このリポジトリは、`fcitx5` 用 IME フロントエンド、Swift 製かな漢字変換サーバー、Qt 設定 UI を 1 つの protobuf プロトコルでつないだプロジェクトです。AI エージェントは、まず `protocol/*.proto` を中心にコンポーネント境界を把握し、その後に変更箇所を各モジュールへ落としてください。

## 先に知るべき構成

- `fcitx5-hazkey/`
  - fcitx5 アドオン本体。キーイベント、preedit、候補 UI を担当します。
- `hazkey-server/`
  - Swift サーバー。UNIX domain socket で要求を受け、`AzooKeyKanaKanjiConverter` を使って変換します。
- `hazkey-settings/`
  - Qt 設定アプリ。サーバー設定を protobuf 経由で読み書きします。
- `protocol/`
  - C++ / Swift / Qt の共通プロトコル定義です。仕様変更の第一入口です。

## 変更ルーティング

### 1. キー入力や候補表示を変えたい

- 入口: `fcitx5-hazkey/src/hazkey_state.cpp`
- 周辺:
  - `fcitx5-hazkey/src/hazkey_preedit.cpp`
  - `fcitx5-hazkey/src/hazkey_candidate.cpp`
  - `fcitx5-hazkey/src/hazkey_server_connector.cpp`

### 2. 変換結果、候補生成、履歴、入力テーブルを変えたい

- 入口: `hazkey-server/Sources/hazkey-server/state.swift`
- 周辺:
  - `hazkey-server/Sources/hazkey-server/config.swift`
  - `hazkey-server/Sources/hazkey-server/keymap.swift`
  - `hazkey-server/Sources/hazkey-server/textConvert.swift`

### 3. ソケット接続やサーバー起動を変えたい

- クライアント側:
  - `fcitx5-hazkey/src/hazkey_server_connector.cpp`
  - `hazkey-settings/serverconnector.cpp`
- サーバー側:
  - `hazkey-server/Sources/hazkey-server/server.swift`
  - `hazkey-server/Sources/hazkey-server/socketManager.swift`
  - `hazkey-server/Sources/hazkey-server/processManager.swift`

### 4. 設定画面や設定項目を変えたい

- UI 入口:
  - `hazkey-settings/mainwindow.ui`
  - `hazkey-settings/mainwindow.cpp`
- タブ別コントローラ:
  - `hazkey-settings/controllers/user_interface_tab_controller.cpp`
  - `hazkey-settings/controllers/conversion_tab_controller.cpp`
  - `hazkey-settings/controllers/input_style_tab_controller.cpp`
  - `hazkey-settings/controllers/ai_tab_controller.cpp`

### 5. 新しい設定項目やコマンドを追加したい

1. `protocol/*.proto` を更新
2. Swift 側の `Protocol/*.pb.swift` を追従
3. サーバーの処理を `protocolHandler.swift` / `state.swift` に追加
4. 必要なら fcitx5 クライアントと Qt 設定 UI も更新

## ソースオブトゥルース

- protobuf の仕様変更は `protocol/base.proto`, `protocol/commands.proto`, `protocol/config.proto` が正です。
- 次のファイルは生成物です。原則として直接編集しません。
  - `hazkey-server/Sources/hazkey-server/Protocol/*.pb.swift`
  - `fcitx5-hazkey` と `hazkey-settings` のビルド時に生成される `*.pb.cc`, `*.pb.h`
  - `hazkey-server/Sources/hazkey-server/constants.swift`
  - `hazkey-settings/constants.h`
  - `fcitx5-hazkey/src/hazkey_constants.h`
- 依存サブモジュールが必須です。`git clone --recursive` 前提で扱ってください。
  - `hazkey-server/azooKey_dictionary_storage`
  - `hazkey-server/azooKey_emoji_dictionary_storage`
  - `hazkey-server/llama.cpp`

## 実行フロー

1. `HazkeyEngine::keyEvent()` が fcitx5 からキーイベントを受けます。
2. `HazkeyState` が `no preedit / preedit / candidate` モードを切り替えます。
3. `HazkeyServerConnector` が protobuf を UNIX socket へ送ります。
4. `hazkey-server` の `SocketManager` が受信し、`ProtocolHandler` が `HazkeyServerState` へ振り分けます。
5. `HazkeyServerState` が変換、候補生成、履歴更新、設定反映を行います。
6. 応答を fcitx5 側の preedit / candidate UI か、Qt 設定 UI が反映します。

## ビルド入口

全体ビルド:

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

コンポーネント単位のビルド:

```sh
cmake -S fcitx5-hazkey -B build/fcitx5-hazkey -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/fcitx5-hazkey

cmake -S hazkey-server -B build/hazkey-server -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/hazkey-server

cmake -S hazkey-settings -B build/hazkey-settings -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/hazkey-settings
```

## 検証の考え方

- プロトコル変更:
  - 少なくとも `hazkey-server` と protobuf を使う C++ 側 2 モジュールを確認します。
- fcitx5 側変更:
  - `fcitx5-hazkey` を優先。ソケットや protobuf を触るなら `hazkey-server` も確認します。
- 設定 UI 変更:
  - `hazkey-settings` を優先。保存項目を増やすなら `protocol/config.proto` と `hazkey-server/config.swift` も確認します。

## 既知の注意点

- サーバーは実質 1 クライアント前提です。`SocketManager` は新規接続時に既存クライアントを閉じます。
- `XDG_RUNTIME_DIR` が無い環境では、サーバーとクライアントでソケットのフォールバック場所が一致しません。起動不良の調査ではここを最初に見てください。
- `hazkey-server` のラッパースクリプトは `$XDG_CONFIG_HOME/hazkey/env` を読み込みます。環境変数注入を追加するならこの流れを壊さない方が安全です。
- `hazkey-settings` の CI では `mainwindow.ui` に対して Qt 互換の `sed` を入れています。Qt バージョン差分で UI ビルドが落ちたら CI の前処理を確認してください。
- `hazkey-server/Tests/` にはテストがありますが、現行 protobuf API と読み比べてから信頼してください。古いテストハーネス由来の型名が残っています。
