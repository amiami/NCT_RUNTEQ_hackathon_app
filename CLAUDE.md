# CLAUDE.md

開発ルールは AGENTS.md に集約しています（Claude Code 以外の AI ツールと共通）。

@AGENTS.md

## Claude Code 固有の設定

- `.claude/settings.json`：よく使う Docker Compose のコマンドは確認なしで実行を許可し、`.env`・`config/master.key` の読み取りと `docker compose down -v` を禁止する（雛形の作成時に追加）
- `.claude/hooks/`：Ruby ファイルの編集後に RuboCop の自動修正をかける（雛形の作成時に追加）
