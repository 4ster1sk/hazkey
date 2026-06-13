# AI Architecture Guide

## 全体像

Hazkey は 3 つの実行コンポーネントと 1 つの共有仕様層で構成されています。

```text
fcitx5 key event
  -> fcitx5-hazkey (C++)
  -> UNIX domain socket protobuf
  -> hazkey-server (Swift)
  -> AzooKeyKanaKanjiConverter + dictionaries
  -> protobuf response
  -> fcitx5 candidate/preedit UI

hazkey-settings (Qt/C++)
  -> UNIX domain socket protobuf
  -> hazkey-server (Swift)
  -> config.json / keymap TSV / table TSV / learning data
```

## コンポーネント別責務

### `fcitx5-hazkey`

- `src/hazkey_engine.cpp`
  - fcitx5 への登録、activate/deactivate、設定再読込。
- `src/hazkey_state.cpp`
  - 入力モード管理の中心。通常入力、変換中、候補選択中の遷移を担当。
- `src/hazkey_preedit.cpp`
  - fcitx の `clientPreedit` / `preedit` 差を吸収。
- `src/hazkey_candidate.cpp`
  - サーバー候補を fcitx の candidate list に変換。
- `src/hazkey_server_connector.cpp`
  - protobuf 送受信、`hazkey-server` 自動起動、再接続処理。

### `hazkey-server`

- `Sources/hazkey-server/server.swift`
  - runtime dir / socket / lock の初期化。
- `Sources/hazkey-server/socketManager.swift`
  - 単一クライアントを前提にしたソケットループ。
- `Sources/hazkey-server/protocolHandler.swift`
  - protobuf oneof から処理メソッドへルーティング。
- `Sources/hazkey-server/state.swift`
  - 変換、候補、履歴、入力モード、cursor、context の中核ロジック。
- `Sources/hazkey-server/config.swift`
  - `config.json`、カスタム keymap/table、Zenzai デバイス、保存先パス。
- `Sources/hazkey-server/keymap.swift`
  - built-in keymap と input table 定義。
- `Sources/hazkey-server/textConvert.swift`
  - ひらがな、カタカナ、英字表現の変換補助。

### `hazkey-settings`

- `mainwindow.cpp`
  - 設定ロード、保存、各タブコントローラの組み立て。
- `serverconnector.cpp`
  - Qt 側のソケットクライアント。セッションモードも持つ。
- `controllers/`
  - タブごとの設定反映。
  - `user_interface_tab_controller.cpp`: 候補数、補助表示、サジェスト系
  - `conversion_tab_controller.cpp`: 学習履歴、特殊変換
  - `input_style_tab_controller.cpp`: keymap / table / submode
  - `ai_tab_controller.cpp`: Zenzai 設定、モデルダウンロード

### `protocol`

- `commands.proto`
  - 通常入力、候補、cursor、modifier などのセッション操作。
- `config.proto`
  - プロファイル、設定 UI、Zenzai、keymap/table 一覧。
- `base.proto`
  - request/response envelope と status code。

## 実行時の重要な流れ

### 1. 文字入力

1. `HazkeyState::keyEvent()` が現在の composing text をサーバーへ問い合わせます。
2. モードに応じて `noPreeditKeyEvent` / `preeditKeyEvent` / `candidateKeyEvent` を使い分けます。
3. サーバーでは `HazkeyServerState.inputChar()` が keymap と submode を解釈します。
4. 候補要求時は `getCandidates()` が `ConvertRequestOptions` を組み立てて converter に流します。

### 2. 候補表示

1. fcitx5 側が `get_candidates` を送ります。
2. サーバーは `predictionResults` と `mainResults` をまとめて `CandidatesResult` を返します。
3. `live_text` と `live_text_index` が auto-convert / predictive UI の鍵です。
4. fcitx5 側は `HazkeyCandidateList` を組み立て、preedit と AUX を同期します。

### 3. 設定保存

1. Qt 側が `get_config` で `CurrentConfig` を取得します。
2. 各タブコントローラが `currentProfile` を編集します。
3. `set_config` で profile 群をサーバーへ送り返します。
4. サーバーは `config.json` を保存し、必要なら `reinitializeConfiguration()` で keymap / table / convert option を作り直します。

## 永続化とパス

### 設定

- `XDG_CONFIG_HOME/hazkey/config.json`
- fallback: `~/.config/hazkey/config.json`

### カスタム keymap / table

- `XDG_CONFIG_HOME/hazkey/keymap/*.tsv`
- `XDG_CONFIG_HOME/hazkey/table/*.tsv`

### 学習履歴と共有キャッシュ

- state: `XDG_STATE_HOME/hazkey/memory`
- cache: `XDG_CACHE_HOME/hazkey/shared`

### Zenzai モデル

- 優先順位:
  1. `HAZKEY_ZENZAI_MODEL`
  2. `XDG_DATA_HOME/hazkey/zenzai/zenzai.gguf`
  3. インストール済み共有データ配下

## 生成物の境界

### 直接編集しない

- `hazkey-server/Sources/hazkey-server/Protocol/*.pb.swift`
- ビルドディレクトリに生成される C++ protobuf ファイル
- `constants.swift`, `constants.h`, `hazkey_constants.h`

### 仕様変更時に先に触る

- `protocol/base.proto`
- `protocol/commands.proto`
- `protocol/config.proto`

## 影響範囲マップ

| 変更内容 | まず触る場所 | 二次影響 |
| --- | --- | --- |
| キー入力の意味を変える | `hazkey-server/keymap.swift`, `state.swift` | `fcitx5-hazkey/hazkey_state.cpp` |
| preedit 表示を変える | `fcitx5-hazkey/hazkey_preedit.cpp`, `hazkey_state.cpp` | `commands.proto` を変えるなら全体 |
| 候補数や auto-convert 条件 | `hazkey-server/state.swift`, `config.proto` | `hazkey-settings` の UI |
| 新しい設定項目 | `config.proto` | `config.swift`, `mainwindow.ui`, 各 controller |
| ソケットや起動方式 | `server.swift`, `socketManager.swift`, connector 2 箇所 | テスト / デスクトップ統合 |
| Zenzai 周り | `config.swift`, `ai_tab_controller.cpp` | install パス、環境変数 |

## AI が見落としやすい点

- fcitx5 と Qt はどちらも同じサーバープロトコルを使うため、通信仕様変更は片側だけ直しても成立しません。
- `HazkeyServerState` は `baseConvertRequestOptions` をキャッシュします。設定保存後に再初期化が必要な理由はここです。
- `SocketManager` は 1 接続モデルです。複数クライアント常駐の前提に変える変更は広く波及します。
- ソケットの fallback path がクライアント側とサーバー側で非対称です。非 GUI 環境の不具合調査で重要です。
