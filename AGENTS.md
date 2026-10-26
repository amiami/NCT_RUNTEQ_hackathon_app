# AGENTS.md — 業務引き継ぎアプリ（仮）

AI 開発ツール（Claude Code・Codex・Cursor・GitHub Copilot など）に共通で読ませる開発ルールです。
人が読んでもチームのルールとして通用するように書いています。ツール固有の設定は各ツールのファイル（`CLAUDE.md` など）に書き、共通のルールはこのファイルに集めます。

## アプリの概要

中小企業の総務・人事部で、**業務マニュアル（業務手順）**と、**担当者ごとの業務の習熟度（スキルレベル）**を管理する Rails アプリです。
新しい業務を担当するときは業務手順を見ながら作業でき、指導役が付く「研修」で業務を引き継ぎます。

今は総務・人事の業務を対象にしていますが、ほかの部署の業務引き継ぎ・スキルマップ・評価にも広げる想定です。

**現在は準備段階**です（雛形はできていますが、モデルや画面はまだありません）。

## アプリの名前

- 画面に出す名前は仮で「業務引き継ぎアプリ」。`config/locales/ja.yml` の `app_name` に1か所だけ書き、ビューでは `t("app_name")` を使う（文字列を直接書かない）
- コードの中の名前は `SkillBridge`（DB は `skill_bridge_development` など、Compose のプロジェクト名は `skill_bridge`）

## 最初に読むもの

| 資料 | 内容 |
|---|---|
| `mock/人事業務ひきつぎアプリ_モックのモック.html` | 画面のモック（4画面：スキル一覧／業務・研修／業務ツリー／改訂履歴） |
| `docs/tech-stack.md` | 技術選定と、それを選んだ理由 |
| `docs/table_design.md` | テーブル設計案 |
| `.agents/knowledge/` | 開発中に分かったこと・つまずいたことの記録（作業前に読む） |

## 用語

| 用語 | 意味 |
|---|---|
| 業務 | 「勤怠締め」「入社手続き」などの仕事の単位。スキル（レベル）を測る単位でもある。テーブルは `operations` |
| マニュアル | 業務のやり方を書いた文書。1業務につき1つ。手順・版・改訂履歴を持つ。テーブルは `manuals` |
| 手順・細目 | マニュアルの中の作業ステップ。業務ツリーでは 業務 → 手順 → 細目 の3階層で表示する。テーブルは `steps`（`manual_id` に属し、`parent_id` で親子） |
| レベル（習熟度） | 担当者 × 業務ごとに 0〜3。0 未経験 / 1 教わりながらできる / 2 一人でできる / 3 人に教えられる |
| 研修 | 新任担当に、指導役（レベル3の人）が業務を教えること。状態は 未着手 → 学習中 → 部長の確認待ち → 研修終了 |
| 改訂 | 業務手順の変更。版（v1, v2…）・改訂理由・変更内容を記録し、関係者が確認する |
| 属人化 | レベル2以上の人が1人以下しかいない業務 |

## 技術構成

Ruby 3.4 / Rails 8.1 / PostgreSQL 17 / Hotwire（Turbo・Stimulus）/ Tailwind CSS v4 / importmap / RSpec / Docker Compose
（選んだ理由と未確定の項目は `docs/tech-stack.md`）

## コマンド（すべて Docker Compose 経由で実行する）

初めての準備（clone からの手順）は `README.md` を見てください。

| 用途 | コマンド |
|---|---|
| 起動 | `docker compose up -d` → http://localhost:3000 |
| DB の作成・更新 | `docker compose run --rm web bin/rails db:prepare` |
| テスト（全部） | `docker compose run --rm web bundle exec rspec` |
| テスト（1ファイル） | `docker compose run --rm web bundle exec rspec spec/path/to_spec.rb` |
| 書き方チェック | `docker compose run --rm web bin/rubocop`（自動修正は `-a`） |
| セキュリティ診断 | `docker compose run --rm web bin/brakeman -q --no-pager` |
| CSS のビルド | `docker compose run --rm css bin/rails tailwindcss:build` |
| ログ | `docker compose logs -f web` |

- **パソコンの Ruby で `bin/rails` などを直接実行しない**（DB はコンテナの中の PostgreSQL なので、つながらない）
- `docker compose down -v` は DB のデータを消すので、人に確認してから実行する

## コーディングルール

- **Rails 標準の命名と構成に従う**（モデルは単数形 `Operation`、テーブルとコントローラは複数形 `operations` / `OperationsController`）
- コントローラは REST の7アクション（index / show / new / create / edit / update / destroy）に収める。それ以外の操作はリソースを分ける（例：研修の承認 → `Trainings::ApprovalsController#create`）
- 1つのモデルで済む処理はモデルに書く。複数のモデルにまたがる処理は `app/services/` に置く
- 画面の動きはまず Turbo（ページやフレームの差し替え）で作り、足りないところだけ Stimulus を使う
- 色・文字サイズはデザイントークン（`app/assets/tailwind/application.css` の `@theme`）の名前で指定し、`#0f6b5c` のような値をビューに直接書かない
- 画面の文言は日本語。日時は日本時間で表示する

## 開発の流れ

1. GitHub Projects で Issue を選び、自分を Assignees に設定して「In progress」に動かす。チャットで「これから◯◯やります」と一言伝える
2. `main` からブランチを作る：`feature/<Issue番号>-<短い英語の説明>`（バグ修正は `fix/…`）
3. **受入条件 → テスト（失敗する）→ 実装（通る）→ リファクタ**の順で進める
4. コミットメッセージは `<種別>: <要約>`。種別は `feat` / `fix` / `refactor` / `test` / `docs` / `chore`。要約は日本語でよい
5. PR は Draft で作り、CI が緑になったら Ready for review にして、Projects で「In review」に動かす。本文に `close #<Issue番号>` を書く
6. **CI が緑 ＋ レビュー承認1名で Squash merge**する

## テストの方針

| 種類 | 何を書くか | 優先度 |
|---|---|---|
| Model spec | バリデーション、レベルの範囲（0〜3）、研修の状態の変わり方、属人化の判定 | 最優先 |
| Request spec | 画面が表示できるか、保存・更新ができるか | 優先 |
| System spec | 主要な流れ1本だけ（研修の割り当て → 終了 → レベルが上がる） | 最小限 |

- `describe` / `it` は日本語で書いてよい
- 日付に関わるテストは `travel_to` で日時を固定する

## ドキュメントのルール

- **仕様と実装がずれたら、実装と同じ PR で `docs/` も直す**
- `docs/` と `README.md` には Issue 番号・ブランチ名・開発の経緯を書かない（あとから読む人向けの資料にする）
- 開発の経緯は PR 本文・コミットメッセージに書く
- 開発中に分かったこと（つまずいて解決したこと、レビューで指摘された型）は `.agents/knowledge/` に短く追記する

## やってはいけないこと

- `.env`・`config/master.key`・API キー・パスワードを読んだり、コミットしたり、チャットや PR に貼ったりしない
- `main` に直接 push しない
- テストを通すためにテストを消したり、`skip` にしたりしない
- Issue に書かれていない機能を勝手に足さない（必要だと思ったら Issue かチャットで提案する）

## AI を使う人へ（チームの約束）

- **AI が書いたコードも、自分で説明できる状態にしてから PR を出す**。レビューで「なぜこう書いたか」に答えられるようにする
- AI の出力が `docs/` やこのファイルのルールと食い違ったら、ルールのほうを優先する。ルール自体を変えたいときはテックリードに相談する
- 15分考えて分からなければ、AI だけで粘らずチームに質問する
