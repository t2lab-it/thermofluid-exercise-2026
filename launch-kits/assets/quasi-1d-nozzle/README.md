# 準一次元ノズルの参照資産

この小規模パックは、比熱比`gamma = 1.4`の等エントロピー面積–Mach数関係を確認するための小さな参照表と事前診断だけを提供します。求根ソルバ、準一次元場のソルバ、境界条件実装、完成実験、完成図、結論は含みません。

## ファイル

- `area-mach-reference.csv`: `A/A*`と亜音速・超音速の解の分枝に対する高精度参照値
- `preflight.jl`: CSVの列、単調性、解の分枝、面積–Mach数関係の残差を確認するCPU向け事前診断

実行:

```bash
julia --startup-file=no preflight.jl
```

事前診断は非対話で、リポジトリへファイルを書きません。実行管理スクリプトから実行する場合はリポジトリ外の一時ディレクトリが`LAUNCH_KIT_OUTPUT_DIR`として渡されますが、この事前診断は出力ファイルを必要としません。

## 出典と転記

- NASA Glenn, “Converging-Diverging Verification (CDV) Nozzle”: <https://www.grc.nasa.gov/www/wind/valid/cdv/cdv.html>
- NASA CDV analytic Mach data, isentropic case `p_exit/p_t = 0.16`: <https://www.grc.nasa.gov/www/wind/valid/cdv/axial.Mex.p16.gen>
- NASA Glenn, “Isentropic Flow Equations”, equation 9: <https://www.grc.nasa.gov/www/k-12/airplane/isentrop.html>
- NASA Images and Media Usage Guidelines: <https://www.nasa.gov/nasa-brand-center/images-and-media/>
- 取得日: 2026-08-11

CSVの値はNASAの式9を`gamma = 1.4`で解いた高精度値です。NASA CDVの解析データとの転記確認として、`A/A* = 2.5`の亜音速値はCSVの`0.23954284305847723`がNASA掲載値`0.2395428`に、`A/A* = 1.5`の超音速値はCSVの`1.8541235267373253`がNASA掲載値`1.854124`に、それぞれ掲載桁で一致します。

NASAを出典として明記し、この教育・情報目的の数値表にはNASAの利用指針を適用します。NASAの記章、ロゴタイプ、画像は再配布していません。

## 学生が決めること

このパックは穴埋め式の完成ソルバではありません。問い、面積関数、境界条件、比較条件、離散化、ソルバ構成、API、関数名、内部ファイル構成、評価指標、実験、図表、解釈は各プロジェクトで決めます。内部衝撃波を扱う場合も、まず等エントロピー縮小ケースを独立に検証してください。
