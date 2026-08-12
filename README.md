# 熱流体力学演習（2026）公開教材

2026年度「熱流体力学演習」の公開Quarto教材サイトです。

公開URL: <https://t2lab-it.github.io/thermofluid-exercise-2026/>

## 必要なローカル環境

- Julia 1.12.6
- Quarto 1.9.31
- Git

Windows、macOS、Linuxのローカル環境を対象にします。Codespaces、devcontainer、Jupyterは使用しません。

## 初期化

```bash
julia --version
quarto --version
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

JuliaとQuartoの表示がそれぞれ`1.12.6`、`1.9.31`であることを確認します。

## レンダリング

macOS・Linux（bash/zsh）では次を実行します。

```bash
QUARTO_JULIA_PROJECT=. quarto render
```

Windows PowerShellでは次を実行します。

```powershell
$env:QUARTO_JULIA_PROJECT = "."
quarto render
```

生成物は`_site/`へ出力されます。`_quarto.yml`はJuliaエンジンを明示します。Julia実行確認用の簡易セルは公開ページに置かず、教員用のリリース予行演習が一時Quartoプロジェクトで検証します。

## テスト

```bash
julia --project=. test/runtests.jl
julia --project=. scripts/verify_contracts.jl \
  assignments/contracts.toml \
  "$(pwd)" \
  /absolute/path/to/thermofluid-exercise-student-2026
```

契約検証には公開教材リポジトリと学生リポジトリのルートディレクトリを明示的に渡します。既存の非公開リポジトリを参照しません。

## ライセンス

Copyright © 2026 荒木 亮（ARAKI, Ryo）

- 教材本文・図: CC BY 4.0
- コード: MIT License

詳細は[LICENSE.md](LICENSE.md)を参照してください。
