# 熱流体力学演習（2026）公開教材

2026年度「熱流体力学演習」の公開Quarto教材サイトです．

公開URL: <https://t2lab-it.github.io/thermofluid-exercise-2026/>

学生向けの課題開始，テスト，学習ログ，PR，mergeの手順は[課題ワークフロー](guides/workflow.qmd)を正本として確認してください．

## 必要なローカル環境

- Julia 1.13系
- Quarto 1.9.31
- Git

WindowsではWSL2 Ubuntu 24.04 LTSのLinux側，macOSではnative macOS，Linuxではnative Linuxを対象にします．
WSL2ではリポジトリをLinux側のホームディレクトリへcloneします．

## バージョン確認

```bash
julia --version
quarto --version
```

Juliaが1.13系，Quartoが`1.9.31`であることを確認します．

## レンダリング

リポジトリのルートで次を実行します．

```bash
env QUARTO_JULIA_PROJECT=. quarto render
```

生成物は`_site/`へ出力されます．
`_quarto.yml`はJuliaエンジンを明示します．
Juliaの実行は，教員用のリリース予行演習が一時Quartoプロジェクトで検証します．

現在の公開ページには実行用のJuliaセルがなく，サイトのテストもJulia標準ライブラリだけを使います．
そのため，通常のレンダリングとテストでは`Pkg.instantiate()`は不要です．
GitHub Pagesのビルドでも依存パッケージのインストールとキャッシュを省き，全テストと全ページのレンダリングを実行します．

ページ単位の表示確認には，対象を指定できます．

```bash
env QUARTO_JULIA_PROJECT=. quarto render lessons/N01.qmd
```

サイト全体の確認や公開前には，対象を指定せず全ページをレンダリングします．

数値計算や実行用のJuliaセルを扱う作業では，依存環境を初期化します．

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

公開ページに実行用のJuliaセルを追加する場合は，GitHub Pagesのビルドにも依存環境の初期化を追加してください．

## テスト

```bash
julia --project=. test/runtests.jl
python3 test/console_examples_test.py
julia --project=. scripts/verify_contracts.jl \
  assignments/contracts.toml \
  "$(pwd)" \
  /absolute/path/to/thermofluid-exercise-student-2026
```

契約検証には公開教材リポジトリと学生リポジトリのルートディレクトリを明示的に渡します．

## 学生ソースへのリンク監査

公開ページの学生コードリンクは`main`を参照します．
監査では，別の一時コピーで取得した学生mainを一度だけSHAへ解決し，同じGitスナップショットと全公開対象QMDを照合します．
既存の学生checkoutや進捗・成果物は変更しません．
以下はfishで実行できます．

```fish
set PUBLIC_ROOT (pwd)
set STUDENT_ROOT (mktemp -d)
git clone --no-checkout https://github.com/t2lab-it/thermofluid-exercise-student-2026.git "$STUDENT_ROOT"
set STUDENT_SHA (git -C "$STUDENT_ROOT" rev-parse refs/remotes/origin/main)
git -C "$STUDENT_ROOT" checkout --detach "$STUDENT_SHA"
julia --project=. scripts/verify_student_source_links.jl "$STUDENT_ROOT" "$PUBLIC_ROOT" --student-revision "$STUDENT_SHA"
```

監査器は学生コードを実行せず，Git objectの種別，関数定義の全範囲（Docstringを除く），定数の宣言行，moduleの参照意図を確認します．
名前空間は表示ラベルと同じ段落のmodule参照から解決し，曖昧な参照や未対応fragmentはエラーとして報告します．
`_quarto.yml`の`project.render`を対象の正本とし，現在のQMDパスとglob形式を読み取ります．
未対応の設定形式では監査を失敗させます．
検証したSHAと各URL，エラー件数を出力し，成功は終了コード0，監査不一致は1，引数の形式が不正な場合は2になります．
監査後にGitHubの学生mainが動いた場合は，新しいSHAと変更パスを確認し，影響するリンクを再監査してください．

通常のテストはオフラインfixtureで完結し，学生リポジトリへのネットワーク接続を要求しません．
既存のN08/N09専用CLIと`source_links`・`check_links`も維持し，単一の定義開始行と関数全体の範囲リンクを検証できます．

## 学生・プロジェクトリポジトリの公開契約

学生用配布リポジトリは公開済みです．
学生が空の公開個人リポジトリを作成し，学生用配布リポジトリをSSHで通常cloneして履歴を保持します．
配布元remoteを`upstream`へ変更し，個人remoteを`origin`として登録して初回pushします．
作成するリポジトリは公開します．
LMSの成績・出欠・個別フィードバックなどの非公開データはGitに置きません．

最終プロジェクトは学生自身が公開リポジトリを作成し，AIと協働して必要な環境を整えます．
[環境構築とコード移行](guides/final-project-handoff.qmd)を参照してください．
## ライセンス

Copyright © 2026 荒木 亮（ARAKI, Ryo）

- 教材本文・図: CC BY 4.0
- コード: MIT License

詳細は[LICENSE.md](LICENSE.md)を参照してください．

## 実行例の書き方

公開ページのシェル実行例は `console`，Julia REPLの実行例は `julia-repl` のコードブロックで書きます．
入力行をそれぞれ `$ `，`julia> ` で始め，直後に期待出力を置きます．
シェルの継続行は `> `，Juliaの継続行は7個の空白で始めます（その後のコードのインデントは保持します）．
`filters/console-examples.lua` が入力と出力を分離し，プロンプトはCSSで表示します．
各入力のQuarto標準コピーボタンは，プロンプトと出力を含めずコピーします．
出力例中の `（…）` は説明・省略を表します．
環境依存の値や，課題完成前後で異なる結果には条件を明記してください．
ファイルへ保存するコードは通常の `julia` などのブロックにし，プロンプトや出力を混ぜません．
このREADMEの保守用コマンドも，直接コピーできる通常のコードブロックです．
