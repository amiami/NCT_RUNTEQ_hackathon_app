# 開発環境の構築

パソコンに Docker と Git があれば開発できます。Ruby・PostgreSQL・Node.js を入れる必要はありません。すべて Docker のコンテナの中で動きます。

## 1. 必要なもの

| もの | 確かめ方 |
|---|---|
| Docker Desktop | `docker compose version` でバージョンが表示される |
| Git | `git --version` でバージョンが表示される |
| GitHub のアカウント | リポジトリ `amiami/NCT_RUNTEQ_hackathon_app` を開ける |

## 2. はじめての準備

```bash
git clone https://github.com/amiami/NCT_RUNTEQ_hackathon_app.git
cd NCT_RUNTEQ_hackathon_app

docker compose build                               # イメージを作る（初回は数分かかる）
docker compose run --rm web bin/rails db:prepare   # DB を作る
docker compose up -d                               # 起動する
```

http://localhost:3000 を開き、「マニュあっぷ」のページに緑色の「保存する」ボタンが表示されれば準備完了です。

テストも1回通しておきます。

```bash
docker compose run --rm web bundle exec rspec
```

## 3. 毎日の始め方

```bash
git switch main
git pull
docker compose up -d
docker compose run --rm web bin/rails db:prepare   # ほかの人が追加したマイグレーションを反映する
```

- Gemfile が変わっていたら `docker compose run --rm web bundle install` も実行します
- 止めるときは `docker compose stop` です

## 4. コンテナの構成（compose.yaml）

Compose のプロジェクト名は `manuup` に固定しています（コンテナ名は `manuup-web-1` など）。

| サービス | 役割 |
|---|---|
| `web` | Rails のサーバー（http://localhost:3000） |
| `css` | Tailwind CSS の監視ビルド。ビューを保存すると CSS が作り直される |
| `db` | PostgreSQL 17。データは名前付きボリューム `postgres` に保存される |

- Gem は名前付きボリューム `bundle` に保存されます
- 画面に出す名前「マニュあっぷ」は `config/locales/ja.yml` の `app_name` に、コードの中の名前 `Manuup`（DB は `manuup_development` など）は `config/application.rb`・`config/database.yml` に書いています

## 5. よく使うコマンド

Rails のコマンドは、パソコンで直接ではなく `docker compose run --rm web` を付けてコンテナの中で実行します。

| 用途 | コマンド |
|---|---|
| 起動 | `docker compose up -d` |
| 停止 | `docker compose stop` |
| DB の作成・更新 | `docker compose run --rm web bin/rails db:prepare` |
| サンプルデータを入れ直す | `docker compose run --rm web bin/rails db:seed:replant` |
| テスト（全部） | `docker compose run --rm web bundle exec rspec` |
| テスト（1ファイル） | `docker compose run --rm web bundle exec rspec spec/path/to_spec.rb` |
| 書き方チェック | `docker compose run --rm web bin/rubocop`（自動修正は `-a`） |
| セキュリティ診断 | `docker compose run --rm web bin/brakeman -q --no-pager` |
| CSS を作り直す | `docker compose run --rm css bin/rails tailwindcss:build` |
| Rails コンソール | `docker compose run --rm web bin/rails console` |
| ログを見る | `docker compose logs -f web` |

## 6. うまく動かないとき

| 症状 | 対処 |
|---|---|
| `Bind for 0.0.0.0:3000 failed: port is already allocated` | ほかのアプリがポート 3000 を使っています。`docker ps` で 3000 を使っているコンテナを確かめて止めるか、`PORT=3001 docker compose up -d` で番号を変えます。止めたあとは `docker compose up -d --force-recreate web` で作り直します |
| `docker compose ps` の `web` の PORTS に `0.0.0.0:3000->3000/tcp` がない | `docker compose up -d --force-recreate web` |
| `ActiveRecord::NoDatabaseError`（`Database not found: manuup_development`） | `docker compose run --rm web bin/rails db:prepare` |
| `ActiveRecord::PendingMigrationError` | `docker compose run --rm web bin/rails db:prepare` |
| 画面に色が付かない | `docker compose logs css` でエラーを確認する。`docker compose run --rm css bin/rails tailwindcss:build` で作り直す |
| `A server is already running` | `docker compose restart web` |
| Gem が見つからない | `docker compose run --rm web bundle install` |
| DB を作り直したい | `docker compose run --rm web bin/rails db:reset`（データは消える） |

- `docker compose down -v` は DB のデータを消します。実行する前にチャンネルで相談してください
- ここにない症状で 30 分調べても解決しないときは、チャンネルで質問してください（[開発の進め方](first-contribution.md#困ったとき)）
- 本番環境の構成とデプロイの流れは [本番環境（デプロイ）](deploy.md) を見てください
