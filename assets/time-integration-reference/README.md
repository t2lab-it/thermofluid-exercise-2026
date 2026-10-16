# 時間積分比較の表示用基準結果

学生配布コードの一時コピーでRK2だけを教員解答により完成させ，教員側`integration-tests/time_integration.jl`の標準CLI検証から生成した．
学生コードの起点は`4bd47d73881290224fbb3196ff37394f620ebf1b`，教員の計算・保存検証は`3c47c2233a858e976f1049946861300a78ed0b0a`と同一の実装を使った．
`time-convergence.png`，`diffusion-comparison.png`，`summary.toml`は必須4手法の結果．
`diffusion-cn.png`と`summary-cn.toml`は任意CNを加えた結果で，元の出力名は`diffusion-comparison.png`と`summary.toml`．
拡散図は3行2列で，左列が$N=128$，右列が$N=4$．
上から最終分布，全手法の高周波係数，陰解法の高周波係数を並べ，学生配布コードの`provided_support.jl`で描画する．
Julia 1.13.0，既存学生Manifest，`GKSwstype=100`で2026-10-16に生成した．
数値条件と再生成の学生向け入口は`advanced/numerical-schemes.qmd`に記載．
