# TVer Client (unofficial)

TVer（ティーバー）の非公式デスクトップ / モバイル向けクライアントです。
Flutter + media_kit（libmpv）で構築し、WebView は使用しません。

An unofficial TVer client for Windows / Linux / Android, built with Flutter and
media_kit (libmpv). No WebView.

## Features

- ホーム：エピソード / シリーズランキング
- 検索（公式 Web アプリと同じキーワード検索 API）
- リアルタイム放送：地上波 5 局（日テレ / テレビ朝日 / TBS / テレ東 / フジテレビ）の
  サイマル配信、放送中・次の番組表示
- ライブ番組（スポーツ中継など単発ライブ）と DVR（見逃し）再生
- カテゴリ（ドラマ / バラエティ / アニメ / ニュース / スポーツ）
- 特集ページ
- 番組表（EPG、当日 ±7 日、放送中番組からライブへ遷移）
- Android：ピクチャインピクチャ（映像のみ表示、自動 / 手動）
- ±10 秒シーク（ライブチャンネル以外）
- Material You（Material 3、ダイナミックカラー対応）

## Build

Requires Flutter (stable) and, for Linux, `clang cmake ninja-build pkg-config
libgtk-3-dev libmpv-dev`. Playback at runtime on Linux needs system libmpv.

```sh
flutter pub get
flutter build apk --release --split-per-abi   # Android
flutter build windows --release               # Windows
flutter build linux --release                 # Linux
```

GitHub Actions (`.github/workflows/ci.yml`) runs `flutter analyze`,
`flutter test` and all three platform builds on every push; pushing a tag
like `v0.2.0` additionally publishes a GitHub Release with the binaries.

## Notes

- 非公式クライアントです。TVer の公開 Web API（未ドキュメント）を公式 Web
  アプリと同じ手順で利用しています。仕様変更で動作しなくなる場合があります。
- 再生は日本国内からのアクセスが必要です（配信側の地域制限によります）。
- DRM 付きで配信される一部コンテンツは再生できません。
- API の調査メモは [docs/api-notes.md](docs/api-notes.md) にあります。

## License

MIT
