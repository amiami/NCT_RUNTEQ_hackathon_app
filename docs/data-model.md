# データ設計（スキルレベル 0〜4 版）

画面と操作の仕様は [仕様書（docs/spec.md）](spec.md) に従います。このファイルは、その仕様を実現するためのテーブルと、レベルが変わるルールをまとめたものです。

## 1. 基本の考え方

- **スキルは「作業」に、版と改訂は「マニュアル」に付ける**。作業1つにマニュアル1つ（1対1）
- **管理者は役職ではなく、users の `admin` フラグで表す**。管理者画面を使えるのは `admin` が true の人
- **スキルを持つ人は `User.skill_holders` の1か所で決める**。いまは管理者以外（スタッフ5人）。スキルマップ・できる人の人数・教わる人の候補は、すべてこのスコープを使う
- **レベルは `skills.level` に今の値を持ち、変わるたびに `skill_level_changes` に記録する**。「申告を取り消す」で前のレベルに戻すため、また「誰が・いつ上げたか」を後から確かめるため
- **管理者の見立ては、レベルとは別に `skills.admin_assessment` で持つ**（▲・▼・▽・◇）。レベルは本人の確認・研修・自己申告だけで変わり、管理者は変えない
- **研修予定は、教わる人1人につき1件**。研修済み（誰から・いつ）は、完了した研修予定から求める
- **マニュアルを読んだかどうかは「どの版まで確認したか」で持つ**。改定で版が上がると、自動的に「再確認」「未読」の状態になる
- **手順はマニュアルの本文に1行＝1ステップで持つ**。ステップ専用のテーブルは作らない
- **画面の言葉とテーブル名**：画面の「作業」は `operations`（GitHub の Issue と紛れないため `tasks` にしない）、「研修予定」は `trainings`

```
users ──< skills >── operations >── categories
  │          └──< skill_level_changes
  │        operations ──1:1── manuals ──< manual_revisions
  └──< trainings（教える人／教わる人） >── operations
```

## 2. ER図

```mermaid
erDiagram
  categories ||--o{ operations : "分類"
  operations ||--|| manuals : "マニュアル"
  manuals ||--o{ manual_revisions : "改訂履歴"
  users ||--o{ manual_revisions : "改定した人"
  users ||--o{ skills : "レベル"
  operations ||--o{ skills : "レベル"
  users ||--o{ skills : "見立てを付けた人"
  skills ||--o{ skill_level_changes : "変更の記録"
  users ||--o{ skill_level_changes : "操作した人"
  operations ||--o{ trainings : "研修予定"
  users ||--o{ trainings : "教える人 / 教わる人"

  users {
    bigint id PK
    string name "名前"
    boolean admin "管理者画面を使えるか"
    integer sort_order "表示順"
  }
  categories {
    bigint id PK
    string name UK "分類名"
    integer sort_order "表示順"
  }
  operations {
    bigint id PK
    bigint category_id FK
    string name "作業名"
    integer sort_order "分類の中での表示順"
    string season_note "時期の目安"
  }
  manuals {
    bigint id PK
    bigint operation_id FK,UK "1作業に1つ"
    integer kind "internal / external"
    text body "手順（1行＝1ステップ）"
    string url "外部サイトのURL"
    integer version "今の版"
  }
  manual_revisions {
    bigint id PK
    bigint manual_id FK
    bigint user_id FK "改定した人"
    integer version "改定後の版"
    text memo "変更内容"
    text body_before "変更前の手順"
    text body_after "変更後の手順"
  }
  skills {
    bigint id PK
    bigint user_id FK
    bigint operation_id FK
    integer level "0〜4"
    integer confirmed_version "確認した版"
    integer admin_assessment "管理者の見立て"
    datetime admin_assessed_at "見立てを付けた日時"
    bigint admin_assessed_by_id FK "見立てを付けた人"
  }
  skill_level_changes {
    bigint id PK
    bigint skill_id FK
    bigint changed_by_id FK "操作した人"
    integer from_level
    integer to_level
    integer reason "変わった理由"
  }
  trainings {
    bigint id PK
    bigint operation_id FK
    bigint trainer_id FK "教える人"
    bigint trainee_id FK "教わる人"
    date due_on "期限"
    integer status "requested / acknowledged / done"
    date done_on "教え終わった日"
  }
```

## 3. テーブル定義

共通：すべてのテーブルに `created_at` / `updated_at` を持つ。改定日などは、特に書かない限り `created_at` を使う。

### users（人）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| name | string | NO | 例：山本 直子 |
| admin | boolean | NO | 管理者画面を使えるか。既定値 false |
| sort_order | integer | NO | 画面での並び順 |

- スコープ `User.skill_holders`：スキルを持つ人。いまは `where(admin: false)`
- 管理者には skills の行を作らない（いまの仕様。将来、管理者にもスキルを持たせるときは、このスコープを変えて行を作る）

### categories（分類）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| name | string | NO | 例：入退社。ユニーク |
| sort_order | integer | NO | 表示順 |

### operations（作業）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| category_id | references | NO | |
| name | string | NO | 例：年末調整 |
| sort_order | integer | NO | 分類の中での表示順 |
| season_note | string | YES | 時期の目安。例：毎年11月中に準備。研修画面の期限の横に目安として表示する（期限の初期値は入れない） |

- インデックス：`[category_id, name]` にユニーク制約

### manuals（マニュアル）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| operation_id | references | NO | ユニーク（1作業に1つ） |
| kind | integer (enum) | NO | `internal: 0`（アプリ内に手順を持つ）, `external: 1`（外部サイトの手順を見る）。画面の表示は「アプリ内」「外部サイト」 |
| body | text | YES | アプリ内の手順。1行＝1ステップ。`internal` のとき必須 |
| url | string | YES | 外部サイトの URL。`external` のとき必須 |
| version | integer | NO | 今の版。既定値 1。画面では「第◯版」と表示する |

- enum の値を `url` にしないのは、同じ名前のカラム `url` と `url?` などのメソッドがぶつかるため
- 将来、アプリ内の手順に参考リンクも付けたくなったら、`internal` のまま `url` も入れられるようにする（バリデーションは「internal なら body 必須」だけにする）
- ステップの一覧は `Manual#steps`（本文を行で分け、空行を除いたもの）で求める
- 最終改定日は、`manual_revisions` のうち `version` が最大の行の `created_at`。改定がなければ「改定なし」

### manual_revisions（改訂履歴）

改定（版を上げる操作）1回につき1行。初版（第1版）の行は作らない。

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| manual_id | references | NO | |
| user_id | references | NO | 改定した人（管理者） |
| version | integer | NO | 改定後の版（2, 3, …） |
| memo | text | YES | 変更内容。空なら「（メモなし）」と表示 |
| body_before | text | YES | 変更前の手順（アプリ内のみ。画面には出さず、記録として残す） |
| body_after | text | YES | 変更後の手順（同上） |

- インデックス：`[manual_id, version]` にユニーク制約

### skills（スキル：スキルを持つ人 × 作業）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| user_id | references | NO | `User.skill_holders` に入る人のみ |
| operation_id | references | NO | |
| level | integer | NO | 0〜4。既定値 0 |
| confirmed_version | integer | YES | 「マニュアルを確認した」を押したときの版。NULL＝一度も確認していない |
| admin_assessment | integer (enum) | YES | 管理者の見立て。`can_train: 0`（▲ 研修権限）, `needs_training: 1`（▼ 要研修）, `training_done: 2`（▽ 研修済み）, `backup_trainer: 3`（◇ 教えるのは後回し）。NULL＝なし |
| admin_assessed_at | datetime | YES | 見立てを付けた日時 |
| admin_assessed_by_id | references (users) | YES | 見立てを付けた人。管理者。「教え終わった」で▽に変わったときは、押した人 |

- インデックス：`[user_id, operation_id]` にユニーク制約
- バリデーション：`level` は 0〜4、ユーザーがスキルを持つ人であること
- **管理者の見立て**
  - 1作業につき1つ。別の見立てを付けると置き換わる（▽に▼や▲を付けたときも同じ）
  - 付けられるレベルは、管理者が付けるときだけ確かめる（サービスで確かめる）：`can_train`・`needs_training` はレベル3、`backup_trainer` はレベル4。`training_done` は「教え終わった」でだけ入る
  - スタッフの操作（自己申告・取り消し）でレベルが変わっても、見立ては自動では外さず、意味も変えない。外せるのは管理者だけ。研修画面での扱い（教える人・教わる人の候補）は、レベルではなく見立ての値で決める
  - 例：3▽が4を申告すると4▽（普通のレベル4として扱い、教える人の候補になる）。3▼が4を申告すると4▼（▼のまま教わる人の候補に残り、教える人の候補には入れない）。見立てや研修予定によって自己申告を弾かない（自己申告は本人の実感の記録で、申告しても研修予定は残るため。続けるか取り消すかは管理者が決める）
  - 値は1つずつ意味を持たせ、レベルによって読み替えない（レベルで読み替えると、申告・取り消しだけで意味が入れ替わるため）
  - `training_done`（▽）は、本人の申告したレベルと管理者の判断が合っていなかった時期があったことを示す。研修済み（誰から・いつ）の表示は ▽ ではなく trainings から求める
  - 付け外しは `skill_level_changes` に記録しない（レベルの変更ではないため）
- スキルを持つ人 × 作業のすべての組み合わせに行を作っておく（シードで作成）
- 判定（その場で計算する）
  - **再確認／未読**（`unread?`）：`confirmed_version` が NULL ではなく、マニュアルの `version` より小さい
  - **確認ボタンを押せる**：`confirmed_version` が NULL か、マニュアルの `version` より小さい

### skill_level_changes（レベル変更の記録）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| skill_id | references | NO | |
| changed_by_id | references (users) | NO | 操作した人（「教え終わった」のときは教える人） |
| from_level | integer | NO | 変更前 |
| to_level | integer | NO | 変更後 |
| reason | integer (enum) | NO | 下の表 |

| reason | 意味 | 変更 |
|---|---|---|
| `confirmed: 0` | マニュアルを確認した | 0 → 1 |
| `trained: 1` | 教え終わった | 0・1 → 2 |
| `self_declared: 2` | 自己申告 | 1・2 → 3、1〜3 → 4 |
| `declaration_undone: 3` | 申告を取り消した | 申告前のレベルへ |

- **レベルが変わらない操作では記録を作らない**（レベル2以上での「教え終わった」、レベル1以上での「マニュアルを確認した」など）
- **申告を取り消せる条件**：その skill の直近の記録が、本人による `self_declared` であること。取り消しの直後は直近の記録が `declaration_undone` になるので、続けて取り消すことはできない（直近の1回だけ）
- **取り消し後のレベル**：その `self_declared` の `from_level`。ただし、その作業で教わる人として `done` の研修予定があり、`from_level` が2未満のときは2にする（研修済みより下げない）。`declaration_undone` を、今のレベルから戻したレベルへの変更として記録する

### trainings（研修予定：教わる人1人につき1件）

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| operation_id | references | NO | |
| trainer_id | references (users) | NO | 教える人。作成時に、その作業でレベル4（▼を除く）か、レベル3で▲（`can_train`）のスキルを持つ人、または管理者（管理者はどの作業でも選べる） |
| trainee_id | references (users) | NO | 教わる人。作成時に、その作業でレベル0・1か、▼（`needs_training`）のスキルを持つ人 |
| due_on | date | YES | 期限。初期値は入れない（空のまま頼むこともできる） |
| status | integer (enum) | NO | `requested: 0`（教える人が未確認）, `acknowledged: 1`（確認済み）, `done: 2`（完了）。既定値 0 |
| done_on | date | YES | 教え終わった日 |

- バリデーション：教える人と教わる人は別の人。同じ作業・同じ教わる人で、完了していない予定は1件まで
- インデックス：`[operation_id, trainee_id]` に、完了していない予定だけを対象にした部分ユニーク制約（`where: "status <> 2"`。2 は `done`）。「変更を保存」の2回押しなどで、同じ人の未完了の予定が2件できるのを DB でも防ぐ
  - SQL の条件には enum の名前を書けないので数字で書く。マイグレーションに `# 2 = done` とコメントを書き、インデックス名は `index_trainings_open_per_trainee` にする。モデルは `enum :status, { requested: 0, acknowledged: 1, done: 2 }` と数字を明示し、モデルスペックで `Training.statuses[:done]` が 2 であることを確かめる。enum の値を変えるときは、このインデックスも作り直す
- 教わる人・教える人のレベルの条件は、作成時だけ確かめる（`on: :create`）。作成後に教わる人・教える人のレベルや管理者の見立てが変わっても（教わる人の自己申告、教える人の申告の取り消しなど）、予定はそのまま続け、確認・完了・期限の変更ができる
- 教える人が管理者のときは、作成時から `acknowledged` にする（管理者自身が頼んだので、通知の帯で確認する必要がない）。画面では「管理者が担当」と表示する
- 完了前は削除できる（「取り消す」）。完了後は削除できない
- **画面での表示**：予定は教わる人ごとに1枚のカードで表示する。「教え終わった」「取り消す」も1件ずつ行う
- **研修画面の保存**：研修画面での変更（予定の追加・取り消し・期限の変更）は、画面の中で下書きとして持ち、「変更を保存」を押したときにまとめて DB に反映する（1つのトランザクションで、予定の作成・削除と `due_on` の更新を行う）。下書きの間は、追加した予定のチップをもう一度押すと取り消せる
  - 「変更を保存」を押せるのは、研修予定の追加、保存済みの研修予定の取り消し、研修予定がある作業（下書きで追加したものも含む）の期限の変更、のどれかがあるとき。保存せずに画面を離れるときの確認（「変更は保存されませんがよろしいですか？」）も、同じ条件のときだけ出す
  - **期限は研修予定にだけ持つ**：研修予定がない作業の期限は保存しない（作業ごとの期限のカラムは作らない）。研修画面のカードの日付は、その作業の未完了の予定の `due_on` を表示し、予定がなければ空にする
- **期限は作業ごと**：研修画面で期限を変えると、その作業の未完了の予定すべての `due_on` が同じ値になる
- **研修済み（誰から・いつ）**：その作業・その教わる人の、`done` の予定のうち最新のもの。教える人の名前と `done_on` を表示する

## 4. レベルが変わるルール

| 操作 | 押す人 | 押せる条件 | 起きること |
|---|---|---|---|
| マニュアルを確認した | スタッフ本人 | 確認ボタンを押せる状態 | `confirmed_version` を今の版にする。レベル0なら1にする |
| 研修を頼む・取り消す・期限を変える（「変更を保存」） | 管理者 | 頼むのは、教わる人がその作業で未完了の予定を持っていないとき。取り消すのは未完了の予定だけ | 追加した予定は教わる人ごとに trainings を1件ずつ作る（教える人が管理者なら `acknowledged` で作る）。取り消した予定は削除する。期限を変えた作業は、未完了の予定の `due_on` をすべて更新する |
| 確認しました（通知の帯） | 教える人 | 自分あての `requested` がある | 自分あての `requested` をすべて `acknowledged` にする |
| 教え終わった | 教える人（管理者が担当の予定は管理者が研修画面から） | 予定が未完了 | その予定を `done` にし、`done_on` を入れる。教わる人がレベル0・1なら2にする（2以上ならそのまま）。教わる人の `confirmed_version` を今の版にする（研修でマニュアルの内容を教わったとみなす。改定後に「再確認」「未読」が出るようにするため）。教わる人の `admin_assessment` が▼（`needs_training`）なら `training_done`（▽）にし、`admin_assessed_at` を今の日時、`admin_assessed_by_id` を押した人にする |
| 先輩のもとでできる | スタッフ本人 | レベル1・2 | レベル3にする |
| 最後まで1人でできる | スタッフ本人 | レベル1〜3 | レベル4にする |
| 申告を取り消す | スタッフ本人 | 直近の記録が本人の自己申告 | その申告の `from_level` に戻す（研修済みなら2より下げない）。管理者の見立ては変えない |
| 管理者の見立てを付ける・外す（スキルマップで選び「変更を保存」） | 管理者 | ▲・▼はレベル3、◇はレベル4のとき | 未決定の変更（複数のマス）を1つのトランザクションでまとめて反映する。どれか1つでも付けられないレベルなら、すべて反映しない。各 skill の `admin_assessment` を変え、`admin_assessed_at`・`admin_assessed_by_id` を入れる。外すときは3つとも NULL にする。レベルは変えない |
| 改定して保存／改定あり | 管理者 | ― | マニュアルの版を1上げ、改訂履歴に1行追加。レベル・管理者の見立て・`confirmed_version` は変えない |

- レベルが変わる操作はすべて、`skills.level` の更新と `skill_level_changes` の追加を1つのトランザクションで行う（`app/services/` に置く）

## 5. その場で計算するもの（テーブルを作らない）

| 画面の要素 | 求め方 |
|---|---|
| できる人◯人 | その作業でレベル4のスキルを持つ人の人数（◇・▼の人も数える）。1人以下で警告 |
| 教える人の候補 | その作業でレベル4の人（▼を除く）と、レベル3＋▲の人、管理者。並び順は、レベル4（◇・▼以外）→ レベル3＋▲ → レベル4＋◇ → 管理者（いつも最後） |
| 研修画面に出す作業 | レベル0・1の人か、▼の人がいる作業 |
| 教わる人の候補 | その作業でレベル0・1の人と▼の人のうち、その作業で未完了の予定がない人 |
| 研修画面の状態（未指示／一部 指示済み／指示済み） | その作業でレベル0・1の人と▼の人のうち、未完了の予定がある人がいなければ「未指示」、一部なら「一部 指示済み」、全員なら「指示済み」 |
| マニュアル確認状況（作業ツリーのスタッフ状況・スキルマップの詳細） | `confirmed_version` が NULL なら「未確認」、マニュアルの `version` より小さければ「改定後 未確認」、同じなら「確認済み」 |
| 研修（作業ツリーのスタッフ状況・スキルマップの詳細） | その作業でその人が教わる人の `done` の予定があれば、最新のものから「済み（教える人の名前から・`done_on`）」。なければ、レベル3以上は「なし（自分で習得）」、それ以外は「まだ」。レベルとは関係なく、完了した予定があれば「済み」になる |
| 改訂のお知らせの件数 | 自分の skill のうち `unread?` のもの |
| 通知の帯 | 自分が教える人で、`requested` の予定 |
| 「本人がレベル3以上に申告済み」の表示（教える予定・指示済みの研修） | 未完了の予定で、教わる人の `admin_assessment` が▼ではなく、教わる人のその作業のレベルが3以上 |
| 研修画面のカードの日付 | その作業の未完了の予定の `due_on`。予定がなければ空 |
| 期限の色 | `due_on` まで14日以内ならオレンジ |

## 6. 管理者の見立てをスタッフに見せない

- スタッフ画面には `admin_assessment`（▲・▼・▽・◇）を出さない。HTML の属性・JSON・Turbo Stream にも出さない
- 管理者画面では、スキルマップのマスと、研修画面の教える人・未研修の名前の横に出す
- Request spec で「スタッフ画面の HTML に、管理者の見立てを表す値が含まれない」ことを確かめる

## 7. テーブルを作らないもの

| 要素 | 方針 |
|---|---|
| ログイン | 作らない。ヘッダーで選んだユーザーを `session[:user_id]` に保存する。何も選んでいないときは管理者 |
| 作業・分類・ユーザーの追加画面 | 作らない。シードで用意する |
| 通知・件数 | テーブルを作らず、その場で計算する |
