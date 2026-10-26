# MultiLangApp

Create multilingual localized app using ASP.NET MVC and deploy onto Azure.

## Development status

As easy deploy to Azure and multilingual support trial had been finished, this project has ended up.

I might clone it again only if I got something to be tried with ASP.NET MVC.

![](media/media.png)

## 使用技術

- Runtime: .NET Framework 4.7.2、ASP.NET MVC 5.2.4 (Windows 専用)
- Packages: NuGet `packages.config` (`packages/` へ復元し、commit しません)
- Docker: 非対応です。ASP.NET MVC 5 on .NET Framework は Windows / IIS が必要です
- Linter: 未導入です
- Tests: unit test は未導入です。CI (`.github/workflows/build.yml`) では Windows 上で次を確認します
    - NuGet restore で脆弱性の警告 (NU1901〜NU1904) が出ないこと
    - `tools/Test-Dependencies.ps1`: `packages.config`・csproj・配信ファイルの version がそろっていること
    - build と、IIS Express でページと bundle が表示でき、log4net がログを書くこと (`tools/Test-Smoke.ps1`)

## パッと実行してみたい

Windows に Visual Studio 2022 以降 (ASP.NET と Web 開発 workload) を入れ、次のコマンドを実行します。

```
nuget restore MultiLangApp.sln
msbuild MultiLangApp.sln /p:Configuration=Release
```

`MultiLangApp.sln` を開いて F5 (IIS Express) を押しても実行できます。Package は自動で復元されます。

画面の言語は browser の `Accept-Language` に従います。`en` なら英語 (`Localize.en.resx`)、それ以外なら日本語 (`Localize.resx`) を表示します。

## bin folder について

以前は clone 後の build が失敗するため、bin folder を commit していました。原因は `packages.config` が空で、csproj の `..\packages\` HintPath に必要な package を NuGet restore が導入できないことでした。現在は `packages.config` に必要な package を記載し、bin folder を build の生成物として扱います。

## ライブラリを更新するとき

`packages.config` の version を上げるだけでは、`Scripts/`・`Content/`・`fonts/` の配信ファイルと csproj の参照は変わりません。package を更新するときは、この 3 つを一緒に更新します。ずれていると `tools/Test-Dependencies.ps1` が失敗します。package を復元したあと `pwsh tools/Test-Dependencies.ps1` を実行すると、手元でも確認できます。

「既知のリスク」Bootstrap 3 は 2019 年にサポートが終了しています。最終版の 3.4.1 にも、修正版のない CVE-2024-6485 (button の `data-loading-text` の XSS) が残ります。このサンプルは button の loading 機能を使っていません。Bootstrap 5 への移行は画面の書き換えが必要なので、行っていません。
