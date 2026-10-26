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
- Tests: 未導入です。CI (`.github/workflows/build.yml`) では Windows 上で package を復元して build します

## パッと実行してみたい

Windows に Visual Studio 2022 (ASP.NET と Web 開発 workload) を入れ、次のコマンドを実行します。

```
nuget restore MultiLangApp.sln
msbuild MultiLangApp.sln /p:Configuration=Release
```

`MultiLangApp.sln` を開いて F5 (IIS Express) を押しても実行できます。Package は自動で復元されます。

画面の言語は browser の `Accept-Language` に従います。`en` なら英語 (`Localize.en.resx`)、それ以外なら日本語 (`Localize.resx`) を表示します。

## bin folder について

以前は clone 後の build が失敗するため、bin folder を commit していました。原因は `packages.config` が空で、csproj の `..\packages\` HintPath に必要な package を NuGet restore が導入できないことでした。現在は `packages.config` に必要な package を記載し、bin folder を build の生成物として扱います。
