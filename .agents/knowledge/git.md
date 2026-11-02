# Git・ブランチ

- 子ブランチに main を取り込んでから epic へ Squash merge すると、main の変更は epic に入るが、取り込んだ履歴は残らない → GitHub や `git rev-list --count` の「main より○コミット遅れ」は減らない。追いついているかはコミット数ではなく `git diff origin/main origin/epic/<ブランチ> --stat` で中身を比べ、epic 側で足した変更だけなら取り込みはいらない。（2026-11-02）
- 上の状態の epic に main をマージすると、両方で行を足した知見ファイル（`.agents/knowledge/*.md`）などで衝突することがある → 中身は両方の行を残せばよい。マージする前に `git merge-tree --write-tree --name-only origin/epic/<ブランチ> origin/main` で衝突するファイルを確かめられる（作業ツリーは変わらない）。（2026-11-02）
- 2つのブランチが `config/locales/ja.yml` の別の場所に同じ親キー（`admin:` など）を足すと、Git は衝突を出さずに両方を残す → YAML は後に書かれたほうだけを使うので、片方の画面の文言が「Translation missing」になる。取り込んだあとは `ja.yml` に同じ親の下で同じキーが2回ないかを確かめ、あれば1つにまとめる。値の形が違う同じキー（文字と `mark`・`label` など）も同じ理由で片方が壊れる。（2026-11-02）
