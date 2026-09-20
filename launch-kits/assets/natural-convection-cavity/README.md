# 二次元自然対流キャビティの参照資産

この小規模パックは、de Vahl Davisの正方形キャビティベンチマークから転記した
`Ra=10^3,10^4`の小さな参照表と、問題設定だけを確認する
CPU向け事前診断を提供します。

## 固定するベンチマーク問題

一辺1の正方形`0 <= x,y <= 1`を、Prandtl数**Pr = 0.71**の
Boussinesq流体で満たします。左壁を高温`theta=1`、右壁を低温
`theta=0`とし、上下壁は断熱です。全壁は滑りなしです。

| 壁 | 速度 | 温度 |
|---|---|---|
| 左、`x=0` | `u=v=0` | `theta=1` |
| 右、`x=1` | `u=v=0` | `theta=0` |
| 下、`y=0` | `u=v=0` | `d theta/dy=0` |
| 上、`y=1` | `u=v=0` | `d theta/dy=0` |

座標原点は左下、`x`は右向き、`y`は上向きです。格子数`N`は
各方向の**境界を含む節点数**で、等間隔幅は`h=1/(N-1)`です。教員の参照計算
は**65 × 65節点**と**129 × 129節点**を比較します。CSVの
`u_max`は`x=0.5`上の水平速度最大値、`y_at_u_max`はその高さ、
`v_max`は`y=0.5`上の鉛直速度の正の最大値、`x_at_v_max`はその位置です。
原論文の`z,w`は、このパックの`y,v`に対応します。

<!-- preflight-contract
schema_version = 1
prandtl = 0.71
domain = [0.0, 1.0, 0.0, 1.0]
grid_nodes = [65, 129]
grid_includes_boundaries = true
grid_spacing = "h=1/(N-1)"
coordinate_origin = "bottom-left"
left_temperature = 1.0
right_temperature = 0.0
horizontal_temperature_boundary = "adiabatic"
velocity_boundary = "no-slip"
-->

## ファイル

- `de-vahl-davis-reference.csv`: Table Vの`Ra=10^3,10^4`ベンチマーク
- `preflight.jl`: CSVの列・2条件・有限値／正の値と、上記の境界・格子
  契約を検証

実行:

```bash
julia --startup-file=no preflight.jl
```

事前診断は参照表と境界・格子の設定を確認し、結果を端末に表示します。

## 出典と来歴

G. de Vahl Davis, “Natural convection of air in a square cavity: A bench mark
numerical solution,” *International Journal for Numerical Methods in Fluids*,
vol. 3, no. 3, pp. 249–264, 1983.

- DOI: <https://doi.org/10.1002/fld.1650030305>
- 出版社情報: <https://onlinelibrary.wiley.com/doi/10.1002/fld.1650030305>
- 使用した表: Table V, “The bench mark solution”
- 取得日: 2026-08-12

CSVには原論文Table Vの全体平均Nusselt数`Nu`を
`nusselt_average`として転記しました。Table Vには壁面値
`Nu_0=1.117,2.238`もありますが、この列には一般にベンチマークとして使われる
`Nu=1.118,2.243`を採用します。論文本文、図、元データのファイルは再配布せず、
6量の2行だけを授業用CSVへ転記しています。授業で作成したREADME、
CSV形式、`preflight.jl`にはリポジトリのライセンスを適用します。

## 学生が決めること

問い、比較パラメータ、
流れ関数–渦度形式以外を含む数値形式、ソルバ構成、Poisson解法、
境界渦度、時間積分、定常判定、API、関数名、実験、図表、解釈は各プロジェクトで
決めます。

まず`Ra=10^3,10^4`、`Pr=0.71`で、Nusselt数、中心線最大速度、
Poisson残差、発散、左右壁熱流束、格子依存性を確認してください。
高Rayleigh数、三次元、乱流、温度依存物性へ進む場合も、この低Rayleigh数の
回帰ケースを残します。
