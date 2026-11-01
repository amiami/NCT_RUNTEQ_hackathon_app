# マニュあっぷ — スキルレベル×マニュアル管理アプリ

人事部の作業ごとに「マニュアル」と「誰がどこまでできるか（スキルレベル）」をまとめて管理し、研修の割り振りまでつなげるアプリです。
マニュアルの改定を誰が読んだか、誰に何を教えたか、できる人が1人しかいない作業はどれかを、管理者が一目で分かることを目指しています。

> 現在は**準備段階**です。開発環境は動きますが、モデルや画面はまだありません。

## はじめての方へ

開発に参加する方は、次の順番で進めてください。

1. **[開発環境の構築](docs/dev/setup.md)** — Docker と Git の準備から、アプリの起動・テストの実行まで
2. **[開発の進め方](docs/dev/first-contribution.md)** — Issue の選び方、ブランチ、コミット、Pull Request を出すまで
3. **[キックオフ資料](docs/kickoff.md)** — プロダクトの目的、チームの役割、開発ルール

困ったら Mattermost の「Aチーム NCT × RUNTEQハッカソン」チャンネルで質問してください。

## タスク管理

| リンク | 内容 |
|---|---|
| [カンバン（GitHub Projects）](https://github.com/users/amiami/projects/3) | Issue の状況（Backlog / Ready / In Progress / Review / Done）。着手する Issue はここの Ready 列から選ぶ |
| [マイルストーン](https://github.com/amiami/NCT_RUNTEQ_hackathon_app/milestones) | M0〜M4 と期限 |
| [エピック一覧](https://github.com/amiami/NCT_RUNTEQ_hackathon_app/issues?q=is%3Aissue+label%3Aepic) | MVP までの大きな要件（エピック）と進み具合 |

## クイックスタート

Docker Desktop と Git が入っていれば、次のコマンドで起動できます（詳しくは [開発環境の構築](docs/dev/setup.md)）。

```bash
git clone https://github.com/amiami/NCT_RUNTEQ_hackathon_app.git
cd NCT_RUNTEQ_hackathon_app
docker compose build
docker compose run --rm web bin/rails db:prepare
docker compose up -d
```

http://localhost:3000 を開くと、管理者の「作業ツリー（マニュアル）」が表示されます（右上のスイッチでスタッフに切り替えると、スタッフの「作業マニュアル」が開きます）。停止は `docker compose stop` です。

## よく使うコマンド

Rails のコマンドは、パソコンで直接ではなく `docker compose run --rm web` を付けてコンテナの中で実行します。

| 用途 | コマンド |
|---|---|
| テスト | `docker compose run --rm web bundle exec rspec` |
| コードの書き方チェック | `docker compose run --rm web bin/rubocop` |
| セキュリティ診断 | `docker compose run --rm web bin/brakeman` |
| DB の作成・更新 | `docker compose run --rm web bin/rails db:prepare` |
| ログを見る | `docker compose logs -f web` |
| CSS を作り直す | `docker compose run --rm css bin/rails tailwindcss:build` |

ほかのコマンドとトラブル対処は [開発環境の構築](docs/dev/setup.md#5-よく使うコマンド) にまとめています。

## ドキュメント

### 仕様

| ドキュメント | 内容 |
|---|---|
| [キックオフ資料](docs/kickoff.md) | 目的とゴール、チームの役割、スケジュール、開発フロー、テスト方針、タスク管理、コミュニケーション |
| [要件定義](docs/requirements.md) | ペルソナ、ユースケース、ユーザーストーリー、受入条件、MVP と拡張の範囲 |
| [画面設計](docs/screens.md) | 画面一覧、画面遷移図、各画面の要素 |
| [仕様書](docs/spec.md) | スキルレベルのルール、各画面の操作、主な流れ、サンプルデータ |
| [データ設計](docs/data-model.md) | ER 図、テーブル定義、レベルが変わるルール |
| 画面モック（`mock/mock.html`） | ブラウザで開くと操作できる画面。見た目の参考で、動きと言葉は仕様書を優先する。`mock/old/` は当初のモックで、参考にしない |

### 開発者向け

| ドキュメント | 内容 |
|---|---|
| [開発環境の構築](docs/dev/setup.md) | 必要なもの、起動、毎日の始め方、よく使うコマンド、トラブル対処 |
| [開発の進め方](docs/dev/first-contribution.md) | Issue → ブランチ → 実装 → コミット → Pull Request の手順、AI を使うときの約束 |
| [本番環境（デプロイ）](docs/dev/deploy.md) | 本番の URL、Render・Neon の設定、デプロイの流れ、困ったときの見方、無料プランの制限 |
| [技術選定](docs/tech-stack.md) | 技術スタックと選んだ理由 |
| [AGENTS.md](AGENTS.md)・[CLAUDE.md](CLAUDE.md) | AI（Codex・Claude Code）で開発するときの前提（自動で読み込まれます） |

## 技術スタック

Ruby 3.4 / Rails 8.1 / PostgreSQL 17 / Hotwire（Turbo・Stimulus）/ Tailwind CSS v4 / importmap / RSpec / Docker Compose

## ディレクトリ構成（主なもの）

```
app/
  models/                  データとルール（1つのモデルで済む処理）
  services/                スキルレベルの変更・改定など、複数のモデルにまたがる処理
  controllers/             画面ごとの処理
  views/                   画面の HTML（ERB）
  javascript/controllers/  画面の動き（Stimulus）
  assets/tailwind/         色・文字などのデザイン設定と部品のクラス
config/routes.rb           URL と処理の対応
db/seeds.rb                サンプルデータ（管理者1名・スタッフ5名・13作業）
spec/                      テスト（RSpec）
docs/                      仕様書
docs/dev/                  開発者向けガイド
mock/                      画面モック（HTML）
.agents/knowledge/         開発中に分かったことの記録
```
