# 熱流体力学演習（2026）公開教材

2026年度「熱流体力学演習」の公開Quarto教材サイトです。

公開URL: <https://t2lab-it.github.io/thermofluid-exercise-2026/>

学生向けの課題開始，テスト，学習ログ，PR，mergeの手順は[課題ワークフロー](guides/workflow.qmd)を正本として確認してください。

## 必要なローカル環境

- Julia 1.13.0
- Quarto 1.9.31
- Git

WindowsではWSL2 Ubuntu 24.04 LTSのLinux側，macOSではnative macOS，Linuxではnative Linuxを対象にします。
WSL2ではリポジトリをLinux側のホームディレクトリへcloneします。

## 初期化

```bash
julia --version
quarto --version
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

JuliaとQuartoの表示がそれぞれ`1.13.0`、`1.9.31`であることを確認します。

## レンダリング

macOS・Linux（bash/zsh）では次を実行します。

```bash
QUARTO_JULIA_PROJECT=. quarto render
```

生成物は`_site/`へ出力されます。
`_quarto.yml`はJuliaエンジンを明示します。
Juliaの実行は、教員用のリリース予行演習が一時Quartoプロジェクトで検証します。

## テスト

```bash
julia --project=. test/runtests.jl
python3 test/console_examples_test.py
julia --project=. scripts/verify_contracts.jl \
  assignments/contracts.toml \
  "$(pwd)" \
  /absolute/path/to/thermofluid-exercise-student-2026
```

契約検証には公開教材リポジトリと学生リポジトリのルートディレクトリを明示的に渡します。

## 学生・プロジェクトリポジトリの公開契約

学生用テンプレートは公開済みです。
個人課題用は学生が公開テンプレートの `Use this template` で自分のアカウントに作成し、SSHでcloneします。
作成するリポジトリは公開します。
LMSの成績・出欠・個別フィードバックなどの非公開データはGitに置きません。

最終プロジェクトは学生自身が公開リポジトリを作成し、AIと協働して必要な環境を整えます。
[環境構築とコード移行](guides/final-project-handoff.qmd)を参照してください。
## ライセンス

Copyright © 2026 荒木 亮（ARAKI, Ryo）

- 教材本文・図: CC BY 4.0
- コード: MIT License

詳細は[LICENSE.md](LICENSE.md)を参照してください。

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
