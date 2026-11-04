# yt-dlp（zipimport zipapp）— 来源链与校验记录

采集日期：2026-11-04。

## 分发产物

| 项 | 值 |
| --- | --- |
| 分发名 | `assets/yt-dlp-zipimport`（media-tools 类 Release 资产；经桌面端 Installer 作为 python 实例 extras 装入，`rel=yt-dlp`） |
| SHA-256 | `1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6` |
| 上游 | [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp) |
| 版本 | `2026.08.19`（2026-11-04 实测 `--version` 输出） |
| 形态 | zipimport zipapp（平台无关；由 Fluixa 从 yt-dlp 源码打包，README 在册） |

## 三方一致性（已实测）

同一 SHA-256 出现在三处（Task E 实测，2026-11-04）：

1. 本仓库 `assets/yt-dlp-zipimport`（media-tools 发布资产）
2. fluixa 主仓库 `extensions/media/tools/darwin-x86_64/yt-dlp-zipimport`（扩展内置副本）
3. 桌面端 Runtime Store python 实例 `~/.fluixa/runtimes/python/3.11.10/darwin-x86_64/yt-dlp`

## 许可证

- **SPDX**: `Unlicense`（yt-dlp 官方 LICENSE 即 Unlicense 文本）。
- 全文：`LICENSE-Unlicense.txt`（yt-dlp 仓库 master 分支 LICENSE，2026-11-04 获取）。
- 版权声明：Unlicense 文本不主张版权（软件释放至公有领域）。

## 边界与未决事项

1. zipapp 打包的是 yt-dlp 本体；yt-dlp 自身的可选依赖（brotli、mutagen、
   pycryptodomex、websockets、certifi 等）在 zipimport 形态下的**实际打包清单未审计**。
   若这些依赖被打入 zipapp，其各自许可证（多BSD/MIT/Apache-2.0，certifi 为 MPL-2.0）
   需要列入清单——状态 `LEGAL_REVIEW_REQUIRED`。
2. 源码对应物：上游 yt-dlp `2026.08.19` tag 源码包未落盘（可按需下载
   `https://github.com/yt-dlp/yt-dlp/archive/refs/tags/2026.08.19.tar.gz` 并记录 SHA-256）。
