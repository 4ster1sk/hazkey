# fcitx5-hazkey

Hazkey input method for fcitx5

[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を利用したIMEです

## ホームページ

[https://hazkey.hiira.dev](https://hazkey.hiira.dev)

## ドキュメント

[https://hazkey.hiira.dev/docs](https://hazkey.hiira.dev/docs)

## インストール

[インストールガイド](https://hazkey.hiira.dev/docs/install)

現在AURと[debianパッケージ](https://github.com/7ka-Hiira/fcitx5-hazkey/releases/latest)が利用できます。

CI では Ubuntu 向け（`ubuntu-22.04` / `ubuntu-24.04`）と Debian 向け（`debian-12`）の `.deb` を別々に生成します。Debian では Ubuntu 24.04 由来の `t64` 依存名を持つパッケージを解決できないため、Debian 12 では `*-debian-12_amd64.deb` を利用してください。

## ビルド

詳細は[ドキュメントのビルドページを参照してください](https://hazkey.hiira.dev/docs/development/build)。

### Dev Container（推奨）

VS Code / Cursor から **Reopen in Container** で開くと、Ubuntu 24.04 ベースの開発環境が自動構築されます。Swift 6.2、CMake 4.1、Qt6、fcitx5、Protobuf などの依存関係はコンテナ内に含まれます。

初回セットアップでは submodule の初期化と CMake の configure が自動実行されます。ビルドは次を実行してください。

```sh
.devcontainer/scripts/build.sh
```

デフォルトは `Debug` ビルドかつ `GGML_VULKAN=OFF` です。変更する場合は環境変数 `HAZKEY_BUILD_TYPE` / `HAZKEY_GGML_VULKAN` を指定してください。

Dev Container の対象はソース取得後のビルドまでです。GUI 起動確認、fcitx5 へのインストール、Wayland/X11 連携はスコープ外です。

### 依存関係

- Swift >= 6.1
- fcitx5 >= 5.0.4
- Qt >= 6.7 (6.2以降でビルド可能ですが表示が崩れる場合があります)
- CMake >= 3.21 (4.x以降推奨)
- Protobuf >= 3.12
- Ninja
- Gettext

### ソースビルド・インストール手順

ホスト Linux に直接 toolchain を入れる場合は、上記の依存関係を満たしたうえで次を実行します。

```sh
git clone --recursive https://github.com/7ka-Hiira/hazkey.git
cd hazkey
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DGGML_VULKAN=OFF -G Ninja ..
ninja
sudo ninja install
```

## ライセンス

[MIT License](./LICENSE)
