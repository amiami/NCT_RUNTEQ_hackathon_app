# マニュあっぷ

中小企業の総務・人事部で、業務マニュアル（業務手順）と担当者ごとの業務の習熟度（スキルレベル）を管理する Rails アプリです。

- 開発ルール：[AGENTS.md](AGENTS.md)
- 技術選定：[docs/tech-stack.md](docs/tech-stack.md)
- テーブル設計：[docs/table_design.md](docs/table_design.md)
- 画面モック：`mock/` の HTML をブラウザで開く

## 必要なもの

- Docker Desktop
- Git

パソコンに Ruby・PostgreSQL・Node.js を入れる必要はありません。すべて Docker のコンテナの中で動きます。

## アプリの名前

| 種類 | 名前 | 書いてある場所 |
|---|---|---|
| 画面に出す名前 | マニュあっぷ | `config/locales/ja.yml` の `app_name`。ビューからは `t("app_name")` で使う |
| コードの中の名前 | `Manuup`（DB は `manuup_development` など） | `config/application.rb`・`config/database.yml` |

## はじめての準備

```sh
git clone https://github.com/amiami/NCT_RUNTEQ_hackathon_app.git
cd NCT_RUNTEQ_hackathon_app

docker compose build                               # イメージを作る（初回は数分かかる）
docker compose run --rm web bin/rails db:prepare   # DB を作る
docker compose up -d                               # 起動する
```

http://localhost:3000 を開き、「マニュあっぷ」のページに緑色の「保存する」ボタンが表示されれば準備完了です。

止めるときは `docker compose stop` です。

## コンテナの構成（compose.yaml）

Compose のプロジェクト名は `manuup` に固定しています（コンテナ名は `manuup-web-1` など）。

| サービス | 役割 |
|---|---|
| `web` | Rails のサーバー（http://localhost:3000） |
| `css` | Tailwind CSS の監視ビルド。ビューを保存すると CSS が作り直される |
| `db` | PostgreSQL 17。データは名前付きボリューム `postgres` に保存される |

- Gem は名前付きボリューム `bundle` に保存されます。Gemfile を変えたら `docker compose run --rm web bundle install` を実行します
- ポート 3000 が使われているときは `PORT=3001 docker compose up -d` で変えられます

## よく使うコマンド

[AGENTS.md](AGENTS.md) の「コマンド」の表を見てください。

## うまく動かないとき

| 症状 | 対処 |
|---|---|
| 画面に色が付かない | `docker compose logs css` でエラーを確認する。`docker compose run --rm css bin/rails tailwindcss:build` で作り直す |
| `A server is already running` | `docker compose restart web` |
| Gem が見つからない | `docker compose run --rm web bundle install` |
| DB を作り直したい | `docker compose run --rm web bin/rails db:reset`（データは消える） |
