# AGENTS.md — マニュあっぷ

AI 開発ツール（Codex・Claude Code など）に共通で読ませる開発ルールです。人向けの手順は `README.md` と `docs/dev/` にあります。

人事部の作業ごとのマニュアルと、スタッフごとのスキルレベル（0〜5）を管理する Rails アプリ。**現在は準備段階**（雛形のみ。モデル・画面は未実装）。

## 最初に読むもの

- 仕様：`docs/spec.md`（画面と操作。食い違ったらこれに従う）、`docs/data-model.md`（テーブルとレベルが変わるルール）
- 画面の見た目：`mock/mock.html`（`mock/old/` は古いので参考にしない）
- 技術選定：`docs/tech-stack.md`
- 開発中の知見：`.agents/knowledge/INDEX.md`（作業前に読む）

## 用語（コードの名前）

| 用語 | 意味・コードでの扱い |
|---|---|
| 管理者・スタッフ | 管理者は `users.admin` が true の人（役職ではない）。スタッフはそれ以外 |
| スキルを持つ人 | **必ず `User.skill_holders` で求める**（いまは管理者以外）。スキルマップ・できる人の人数・教わる人の候補もこのスコープを使う |
| 分類・作業 | `categories`・`operations`（`tasks` にしない） |
| マニュアル | `manuals`。1作業に1つ。`kind` は `internal`（アプリ内に手順）／`external`（外部サイト）。版と改訂履歴（`manual_revisions`）を持つ |
| 手順 | `manuals.body` に1行＝1ステップ。ステップ用のテーブルは作らない |
| レベル | `skills.level`（0〜5）。0 未着手 / 1 マニュアル確認済み / 2 研修済み / 3 先輩のもとでできる / 4 最後まで1人でできる / 5 安心して任せられる（管理者が承認）。変わるたびに `skill_level_changes` に記録する |
| レベル5 | **スタッフには見せない**。スタッフ画面では4として出し、HTML の属性・JSON・Turbo Stream にも5を出さない。表示用の値は `Skill#level_for(viewer)` で求め、ビューで `level` を直接使わない |
| 研修予定 | `trainings`。教わる人1人につき1件。`requested` → `acknowledged` → `done` |
| 改定 | マニュアルの版を上げる（管理者だけ）。その作業のレベル5の人を4に戻す |
| できる人 | その作業でレベル4以上の人。1人以下なら警告 |

画面の名前は「マニュあっぷ」（`t("app_name")` で使い、文字列を直接書かない）。コードの中は `Manuup`。

## コマンド（すべて Docker Compose 経由）

| 用途 | コマンド |
|---|---|
| 起動 | `docker compose up -d` → http://localhost:3000 |
| DB の作成・更新 | `docker compose run --rm web bin/rails db:prepare` |
| テスト | `docker compose run --rm web bundle exec rspec`（1ファイルなら `spec/path/to_spec.rb` を付ける） |
| 書き方チェック | `docker compose run --rm web bin/rubocop`（自動修正は `-a`） |
| セキュリティ診断 | `docker compose run --rm web bin/brakeman -q --no-pager` |
| CSS のビルド | `docker compose run --rm css bin/rails tailwindcss:build` |
| ログ | `docker compose logs -f web` |

- パソコンの Ruby で `bin/rails` などを直接実行しない（DB はコンテナの中の PostgreSQL）
- `docker compose down -v` は DB のデータを消すので、人に確認してから実行する

## コーディングルール

- Rails 標準の命名と構成に従う。表示順のカラムは `sort_order`（`position` にしない）
- コントローラは REST の7アクションに収め、それ以外の操作はリソースを分ける（例：レベル5の承認 → `Skills::ApprovalsController#create`）
- 1つのモデルで済む処理はモデルに、複数のモデルにまたがる処理は `app/services/` に書く
- **レベルを変える処理は、`skills.level` の更新と `skill_level_changes` の追加を1つのトランザクションで行う**（`app/services/` に置く。`level` を直接書き換えない）
- 画面の動きはまず Turbo で作り、足りないところだけ Stimulus を使う
- UI 部品ライブラリは使わない。色・文字は `app/assets/tailwind/application.css` の `@theme` のトークン名で指定し、16 進数をビューに書かない。ボタン・バッジ・カードなどの見た目は同じファイルの `@layer components` にまとめ、ビューに `style` を書かない
- 画面の文言は日本語。日時は日本時間で表示する

## テストの方針

- 受入条件 → テスト（失敗する）→ 実装（通る）→ リファクタの順で進める
- 最優先：Model spec（バリデーション、レベル 0〜5、スキルを持つ人以外の Skill は作れない、研修予定のルール、できる人の判定）と、レベルを変えるサービス・改定の spec（`skill_level_changes` の記録、申告の取り消しは1回だけ、改定で5→4）
- Request spec：表示・保存に加えて、**スタッフ画面の HTML にレベル5を表す値が含まれないこと**
- System spec は主要な流れ1本だけ（研修を頼む → 教え終わった → 教わった人がレベル2になる）
- `describe` / `it` は日本語でよい。日付に関わるテストは `travel_to` で固定する

## 開発の流れ（詳しくは `docs/dev/first-contribution.md`）

- ブランチ：エピックの子 Issue は `epic/<番号>-<説明>` から `feature/<番号>-<説明>`（バグは `fix/…`）を作る。エピックに入らない小さな作業は `main` から作る
- コミット：`<feat|fix|refactor|test|docs|chore>: <要約>`（要約は日本語でよい）
- PR は Draft で作り、本文に `Closes #<番号>` を書く。子 PR → epic は CI 緑で Squash merge、epic → `main` は CI 緑 ＋ 承認1名（設計に関わる変更はテックリード）で Merge commit
- 仕様と実装がずれたら、実装と同じ PR で `docs/` も直す。`docs/` と `README.md` には Issue 番号・ブランチ名・経緯を書かない（経緯は PR とコミットに書く）
- 分かったこと・つまずいて解決したことは `.agents/knowledge/` に短く追記する

## やってはいけないこと

- `.env`・`config/master.key`・API キー・パスワードを読む、コミットする、チャットや PR に貼る
- `main` と epic ブランチに直接 push する（必ず PR を通す）
- テストを通すためにテストを消す・`skip` にする
- Issue に書かれていない機能を勝手に足す（必要なら Issue かチャンネルで提案する）
- ルール（このファイル・`docs/`）と食い違うコードを書く。ルールを変えたいときはテックリードに相談する
