# AGENTS.md — マニュあっぷ

AI 開発ツール（Claude Code・Codex・Cursor・GitHub Copilot など）に共通で読ませる開発ルールです。
人が読んでもチームのルールとして通用するように書いています。ツール固有の設定は各ツールのファイル（`CLAUDE.md` など）に書き、共通のルールはこのファイルに集めます。

## アプリの概要

中小企業の人事部で、**作業ごとのマニュアル（手順）**と、**スタッフごとの作業の習熟度（スキルレベル 0〜5）**を管理する Rails アプリです。
スタッフはマニュアルを見ながら作業し、自分のレベルを申告します。管理者は研修（できる人が教わる人に教える）を頼み、マニュアルを改定し、レベル5を承認します。

今は人事の作業を対象にしていますが、ほかの部署の業務引き継ぎ・スキルマップ・評価にも広げる想定です。

**現在は準備段階**です（雛形はできていますが、モデルや画面はまだありません）。

## アプリの名前

- 画面に出す名前は「マニュあっぷ」。`config/locales/ja.yml` の `app_name` に1か所だけ書き、ビューでは `t("app_name")` を使う（文字列を直接書かない）
- コードの中の名前は `Manuup`（DB は `manuup_development` など、Compose のプロジェクト名は `manuup`）

## 最初に読むもの

| 資料 | 内容 |
|---|---|
| `mock/mock.html` | 画面のモック（ブラウザで開く。管理者とスタッフの両方の画面がある）。当初のモックは `mock/old/` にあるが、参考にしない |
| `mock/mock-spec.md` | モックの画面と操作の仕様。画面の動きはこれに従う |
| `docs/data-model.md` | テーブル設計と、レベルが変わるルール |
| `docs/tech-stack.md` | 技術選定と、それを選んだ理由 |
| `.agents/knowledge/` | 開発中に分かったこと・つまずいたことの記録（作業前に読む） |

## 用語

| 用語 | 意味 |
|---|---|
| 管理者・スタッフ | 管理者は役職ではなく「管理者画面も使える人」で、`users.admin` が true。スタッフは `admin` が false の人 |
| スキルを持つ人 | スキル（レベル）を持つ人。**必ず `User.skill_holders` で求める**（いまは管理者以外）。スキルマップ・できる人の人数・教わる人の候補も、すべてこのスコープを使う |
| 分類 | 「入退社」などの作業のまとまり。テーブルは `categories` |
| 作業 | 「年末調整」などの仕事の単位。スキル（レベル）を測る単位でもある。テーブルは `operations`（GitHub の Issue と紛れないため `tasks` にしない） |
| マニュアル | 作業のやり方。1作業に1つ。版と改訂履歴を持つ。テーブルは `manuals`。種類（`kind`）は `internal`（アプリ内に手順を持つ）／`external`（外部サイトの手順を見る）で、画面の表示は「アプリ内」「外部サイト」 |
| 手順 | マニュアルの中の作業ステップ。`manuals.body` に**1行＝1ステップ**で持つ（ステップ用のテーブルは作らない）。一覧は `Manual#steps` で求める |
| レベル（習熟度） | スキルを持つ人 × 作業ごとに 0〜5（`skills.level`）。0 未経験 / 1 マニュアルを確認した / 2 研修済み / 3 先輩のもとでできる / 4 最後まで1人でできる / 5 管理者が承認。変わるたびに `skill_level_changes` に記録する |
| レベル5 | 管理者だけが承認・取り消しできる。**スタッフには見せない**（スタッフ画面では4として表示し、HTML の属性・JSON・Turbo Stream にも5を出さない。表示用の値は `Skill#level_for(viewer)` で求め、ビューで `level` を直接使わない） |
| 研修予定 | 教える人（その作業がレベル4以上の人、または管理者）が教わる人に作業を教える予定。**教わる人1人につき1件**。テーブルは `trainings`。状態は `requested`（教える人が未確認）→ `acknowledged`（確認済み）→ `done`（完了） |
| 改定 | マニュアルの版を上げる操作（管理者だけ）。改訂履歴（`manual_revisions`）に1行追加し、その作業のレベル5の人を4に戻す |
| できる人 | その作業でレベル4以上のスキルを持つ人。1人以下なら警告する |

## 技術構成

Ruby 3.4 / Rails 8.1 / PostgreSQL 17 / Hotwire（Turbo・Stimulus）/ Tailwind CSS v4（UI 部品ライブラリは使わない）/ importmap / RSpec / Docker Compose
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
- 表示順のカラムは `position` ではなく `sort_order` にする（「ポジション（役職）」と紛れないため）
- コントローラは REST の7アクション（index / show / new / create / edit / update / destroy）に収める。それ以外の操作はリソースを分ける（例：レベル5の承認 → `Skills::ApprovalsController#create`）
- 1つのモデルで済む処理はモデルに書く。複数のモデルにまたがる処理は `app/services/` に置く
- **レベルを変える処理は、`skills.level` の更新と `skill_level_changes` の追加を1つのトランザクションで行う**（`app/services/` に置く。`level` を直接書き換えない）
- 画面の動きはまず Turbo（ページやフレームの差し替え）で作り、足りないところだけ Stimulus を使う
- 色・文字サイズはデザイントークン（`app/assets/tailwind/application.css` の `@theme`）の名前で指定し、`#0f6b5c` のような値をビューに直接書かない
- 部品（ボタン・バッジ・カードなど）の見た目は、`application.css` の `@layer components` のクラスにまとめる。ビューに直接 `style` を書かない
- 画面の文言は日本語。日時は日本時間で表示する

## 開発の流れ

機能の Issue はエピック（`[epic]` の Issue）ごとにまとめ、エピックのブランチで開発します。

1. GitHub Projects の「Ready」から Issue を選び、自分を Assignees に設定して「In progress」に動かす。チャットで「これから◯◯やります」と一言伝える
2. ブランチを作る
   - エピックの子 Issue：エピックのブランチ `epic/<エピック番号>-<短い英語の説明>`（例：`epic/28-data-foundation`）から、`feature/<Issue番号>-<短い英語の説明>` を作る（バグ修正は `fix/…`）
   - エピックに入らない小さな修正：`main` から作る
3. **受入条件 → テスト（失敗する）→ 実装（通る）→ リファクタ**の順で進める
4. コミットメッセージは `<種別>: <要約>`。種別は `feat` / `fix` / `refactor` / `test` / `docs` / `chore`。要約は日本語でよい
5. PR は Draft で作り、CI が緑になったら Ready for review にして、Projects で「In review」に動かす。本文に `Closes #<Issue番号>` を書く（Issue が自動で閉じるのは `main` に入ったときだけ）
6. マージ
   - 子 Issue の PR（向き先はエピックのブランチ）：**CI が緑なら Squash and merge**
   - まとめの PR（エピックのブランチ → `main`）：**CI が緑 ＋ レビュー承認1名で Create a merge commit**。本文にはエピックと子 Issue の番号を全部並べる
   - 小さな修正の PR（向き先は `main`）：**CI が緑 ＋ レビュー承認1名で Squash and merge**

## テストの方針

| 種類 | 何を書くか | 優先度 |
|---|---|---|
| Model spec | バリデーション、レベルの範囲（0〜5）、スキルを持つ人以外の Skill は作れないこと、研修予定のルール（教える人と教わる人は別、未完了は1件まで）、できる人の判定（レベル4以上が1人以下で警告） | 最優先 |
| Service spec | レベルを変えるサービス（`skill_level_changes` に記録されること、申告の取り消しは1回だけ）、改定（版が上がり、レベル5の人が4になる） | 最優先 |
| Request spec | 画面が表示できるか、保存・更新ができるか、**スタッフ画面の HTML にレベル5を表す値が含まれないこと** | 優先 |
| System spec | 主要な流れ1本だけ（研修を頼む → 教え終わった → 教わった人のレベルが2になる） | 最小限 |

- `describe` / `it` は日本語で書いてよい
- 日付に関わるテストは `travel_to` で日時を固定する

## ドキュメントのルール

- **仕様と実装がずれたら、実装と同じ PR で `docs/` も直す**
- `docs/` と `README.md` には Issue 番号・ブランチ名・開発の経緯を書かない（あとから読む人向けの資料にする）
- 開発の経緯は PR 本文・コミットメッセージに書く
- 開発中に分かったこと（つまずいて解決したこと、レビューで指摘された型）は `.agents/knowledge/` に短く追記する

## やってはいけないこと

- `.env`・`config/master.key`・API キー・パスワードを読んだり、コミットしたり、チャットや PR に貼ったりしない
- `main` とエピックのブランチに直接 push しない（必ず PR を通す）
- テストを通すためにテストを消したり、`skip` にしたりしない
- Issue に書かれていない機能を勝手に足さない（必要だと思ったら Issue かチャットで提案する）

## AI を使う人へ（チームの約束）

- **AI が書いたコードも、自分で説明できる状態にしてから PR を出す**。レビューで「なぜこう書いたか」に答えられるようにする
- AI の出力が `docs/` やこのファイルのルールと食い違ったら、ルールのほうを優先する。ルール自体を変えたいときはテックリードに相談する
- 15分考えて分からなければ、AI だけで粘らずチームに質問する
