# 一次元Stefan問題の参照資産

この小規模パックは、一次元一相融解問題の相似解から作った界面位置表と、その物理・無次元パラメータの整合だけを確認するCPU向け事前診断を提供します。

## 固定する縮小ケース

| 量 | 値 |
|---|---:|
| 密度 $\rho$ | $1000\ \mathrm{kg\,m^{-3}}$ |
| 比熱 $c_p$ | $1000\ \mathrm{J\,kg^{-1}\,K^{-1}}$ |
| 熱伝導率 $k$ | $1\ \mathrm{W\,m^{-1}\,K^{-1}}$ |
| 潜熱 $L$ | $100000\ \mathrm{J\,kg^{-1}}$ |
| 領域 | $0 \le x \le 0.1\ \mathrm{m}$ |
| 初期温度 | $T(x,0)=T_m=0\ ^\circ\mathrm{C}$ |
| 左端境界 | $T(0,t)=10\ ^\circ\mathrm{C}$ |
| 右端境界 | $T(0.1,t)=T_m=0\ ^\circ\mathrm{C}$ |
| 相変化温度 | $T_m=0\ ^\circ\mathrm{C}$ |

この設定では

$$
\alpha = \frac{k}{\rho c_p}=10^{-6}\ \mathrm{m^2\,s^{-1}},\qquad
\mathrm{Ste}=\frac{c_p(T_\mathrm{left}-T_m)}{L}=0.1.
$$

一相相似解の界面は

$$
s(t)=2\lambda\sqrt{\alpha t},
$$

$$
\sqrt{\pi}\,\lambda e^{\lambda^2}\operatorname{erf}(\lambda)
=\mathrm{Ste}
$$

で与えられ、このケースでは $\lambda=0.2200162727429379$ です。液相内の温度は

$$
T(x,t)=T_\mathrm{left}
-(T_\mathrm{left}-T_m)
\frac{\operatorname{erf}\!\left(x/(2\sqrt{\alpha t})\right)}
{\operatorname{erf}(\lambda)}
\quad (0\le x\le s(t))
$$

です。有限領域の右端は、収録した最終時刻でも界面から十分遠く、$T_m$に固定します。

## ファイル

- `similarity-reference.csv`: 時刻、相似界面位置、左右境界温度
- `preflight.jl`: CSV列、単調性、物性から計算した$\alpha$、Stefan数、$\lambda$、界面式の整合を確認

実行:

```bash
julia --startup-file=no preflight.jl
```

事前診断はCSVと物理・無次元パラメータの整合を確認し、結果を端末に表示します。

## 出典と来歴

固定格子エンタルピー法と一次元Stefanベンチマークの出発点は、Voller, Cross, Markatos, “An enthalpy method for convection/diffusion phase change,” <https://doi.org/10.1002/nme.1620240119> です。このリポジトリは論文本文や図を再配布せず、上記の古典的一相式から授業用CSVを独立に計算しています。

CSV生成日: 2026-08-11。数値はJulia 1.12.6のFloat64で上式を二分法により評価したものです。

## 学生が決めること

問い、比較パラメータ、相変化温度幅、エンタルピー–温度対応、離散化、時間積分、ソルバ構成、API、関数名、内部ファイル構成、界面抽出、評価指標、実験、図表、解釈は各プロジェクトで決めます。まずこの一相ケースで界面位置とエネルギー収支を検証してから発展へ進んでください。
