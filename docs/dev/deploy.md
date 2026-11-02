# 本番環境（デプロイ）

本番環境の構成と設定、デプロイの流れ、困ったときの見方をまとめます。

- 本番の URL：https://manuup.onrender.com
- Render と Neon のアカウントは、たかやまが持っています。設定を変えたいときは、チャンネルで声をかけてください

## 1. 構成

```
GitHub（main ブランチ） ──自動デプロイ──▶ Render（Web Service・Docker） ──▶ Neon（PostgreSQL）
```

| もの | 役割 |
|---|---|
| GitHub | `main` ブランチのコードが本番に出る |
| Render | リポジトリの `Dockerfile` からイメージを作り、アプリを動かす |
| Neon | 本番の PostgreSQL |

## 2. 設定した内容

### Render（Web Service）

| 項目 | 値 |
|---|---|
| 名前 | `manuup` |
| 種類 | Web Service（Docker） |
| ブランチ | `main` |
| 地域 | Singapore |
| プラン | Free |
| Health Check Path | `/up` |
| Auto-Deploy | On Commit |

### Neon（PostgreSQL）

| 項目 | 値 |
|---|---|
| 地域 | Singapore |
| PostgreSQL | 17 |
| ブランチ | `production` |
| DB 名 | `manuup_production` |
| Connection pooling | オフ |

### 環境変数（Render に設定）

値は秘密なので、ここには名前だけを書きます。値をチャットや PR に貼らないでください。

| 名前 | 内容 |
|---|---|
| `DATABASE_URL` | Neon の接続文字列 |
| `SECRET_KEY_BASE` | `docker compose run --rm web bin/rails secret` で作った値 |

## 3. デプロイの流れ

1. Pull Request を `main` にマージする
2. Render が `main` の更新を見つけて、自動でイメージを作り直す
3. コンテナの起動時に `bin/rails db:prepare` が走り、DB の作成・マイグレーションが行われる（`bin/docker-entrypoint`）
4. Health Check（`/up`）が通ると、新しい版に切り替わる

手でデプロイする操作はいりません。

### サンプルデータ（seeds）

- 本番の DB が未初期化（テーブルがまだない）ときは、最初のデプロイの `db:prepare` がテーブルとサンプルデータ（`db/seeds.rb`）を入れる。テーブルがあれば、データが0件でも seeds は自動では入らない
- seeds は何度実行しても二重にならない作り。データを入れ直したいときは、チャンネルで相談する

## 4. うまく動かないとき

Render のダッシュボードで `manuup` を開き、次の画面を見ます。

| 画面 | 見るもの |
|---|---|
| Events | デプロイの成功・失敗の履歴。失敗したデプロイを開くと、ビルドのログが見られる |
| Logs | 起動中のアプリのログ。起動時の `db:prepare` のエラーや、画面を開いたときのエラーが出る |

| 症状 | 見るところ |
|---|---|
| デプロイが失敗する | Events で失敗したデプロイのログを開く。イメージを作るところ（`bundle install`・アセットのビルド）で止まっていないか |
| デプロイは進むが切り替わらない | Logs で起動時のエラーを見る。DB に接続できない・マイグレーションに失敗している・環境変数が足りない、など |
| 画面を開くとエラーになる | Logs でエラーの内容を見る |

## 5. 無料プランの制限

| サービス | 制限 |
|---|---|
| Render（Free） | しばらく使わないと止まる。止まったあとの最初のアクセスは、起動に50秒以上かかることがある |
| Neon（Free） | 容量 1GB・月 100 コンピュート時間。使わないと自動で止まる（次の接続で起動する） |

- デモの前に一度本番を開いて、起こしておいてください
