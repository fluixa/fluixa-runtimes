# Python Runtime — 来源链与校验记录

采集日期：2026-11-04。

## 分发产物

| 项 | 值 |
| --- | --- |
| 分发名 | `cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz` |
| catalog version | `3.11.10` |
| SHA-256 | `575b49a7aa64e97b06de605b7e947033bf2310b5bc5f9aedb9859d4745033d91`（`checksums/SHA256SUMS` 在册） |
| 上游 | [astral-sh/python-build-standalone](https://github.com/astral-sh/python-build-standalone) release `20241016`（relocatable CPython 发行版） |
| URL 来源链 | fluixa 官方镜像 → Gitee 镜像 → pbs 上游（catalog `urls`，三者同 sha256，Installer 校验） |
| 实测 | `python3.11 --version` → `Python 3.11.10`；`yt-dlp --version` → `2026.08.19`（tool extra） |

## 许可证

- **SPDX**: `PSF-2.0`（CPython 主许可）。
- 全文：`LICENSE-PSF-2.0.txt`（取自 CPython 仓库 **v3.11.10 tag** 的 `LICENSE` 文件——
  与分发版本精确对应，含 PSF-2.0 许可正文与历史贡献者版权列表）。
- 版权：Python Software Foundation 及历史贡献者（见该 LICENSE 文件的 HISTORY 段）。

## 边界与未决事项

1. python-build-standalone 发行版除 CPython 外还捆绑了三方组件
   （OpenSSL、libffi、expat、SQLite、xz、mpdecimal 等）。**逐组件 SPDX 清单未完成**，
   状态 `LEGAL_REVIEW_REQUIRED`。获取路径：pbs release 的构建记录 / `make build` 清单。
2. 本实例内置 extras（`yt-dlp` zipapp、`cacert.pem`）的许可证分别记录于
   `../yt-dlp/` 与 `../cacert/`，不在此重复。
