# fluixa-runtimes

> English version: [README.md](./README.md)

Fluixa Runtime Distribution —— Fluixa 运行时工件的**独立分发层**。
**Catalog → Artifact → SHA-256 校验 → GitHub / Gitee / 未来 CDN →
Fluixa Runtime Installer → `~/.fluixa/runtimes/` → Runtime Resolver。**

本仓库只负责分发：存在哪些工件、从哪里下载、字节身份是什么。它从不执行
任何程序，也从不依赖任何 Fluixa 组件。消费方（`fluixa` 主仓库
`crates/runtime-store`）通过以下地址发现 Catalog：

```
https://raw.githubusercontent.com/fluixa/fluixa-runtimes/main/catalog.json
```

（可用 `FLUIXA_RUNTIME_CATALOG` 覆盖 —— URL 或本地文件。）

## 仓库地址

```text
GitHub: fluixa/fluixa-runtimes
Gitee:  fluixa/fluixa-runtimes
```

## 仓库结构

```text
catalog.json              ← 已发布的 Catalog（仓库根目录，main 分支）
assets/                   ← 各运行时的辅助文件，作为 Release 资产发布
  yt-dlp-zipimport          yt-dlp 2026.08.19 zipapp（平台无关）
  cacert.pem                certifi 2026.7.22 CA bundle
artifacts/                ← 本地 artifact 缓存（gitignore；可用
  python/3.11.10/…          verify_catalog.py --fetch 重新下载）
checksums/SHA256SUMS      ← artifacts/ + assets/ 的入库指纹
scripts/
  gen_catalog.py            catalog ↔ artifact 字节一致性维护（--update/--fetch）
  verify_catalog.py         发布门禁校验（schema/重复/镜像/字节/URL 探测）
  release.sh                GitHub Draft Release + Gitee 镜像清单
docs/
  catalog-v1.md             Catalog schema 规范（英文，与 runtime-store 语义一一对应）
  catalog-v1.zh-CN.md       Catalog schema 规范（简体中文）
  release.md                命名 / tag / GitHub-Gitee-CDN 镜像（英文 Runbook）
  release.zh-CN.md          发布 Runbook（简体中文，实际走通流程完整记录）
  verification-*.md         按日期的兼容性验证记录（英文）
```

## 快速开始

```sh
python3 scripts/verify_catalog.py --fetch          # 下载缺失 artifact + 全量校验
python3 scripts/verify_catalog.py --upstream --check-urls   # + 官方交叉校验 + URL 探测
python3 scripts/gen_catalog.py --update            # 刷新 size/sha256 + checksums/SHA256SUMS
scripts/release.sh python-3.11.10                  # 发布 GitHub Draft Release
```

## Fluixa 如何消费

```text
catalog.json → load_catalog → select(kind)
   → install_from_catalog: urls[] 顺序 fallback（primary→mirror1→…）
       → size + SHA-256 校验（mismatch 直接中止，绝不绕过）
       → extract → RUNTIME_MANIFEST.json + extras（yt-dlp、cacert.pem）
       → 原子发布 → ~/.fluixa/runtimes/<kind>/<version>/<platform-arch>/
   → CURRENT.json → Runtime Resolver → interpreter / tool / SSL_CERT_FILE
```

Installer 会把辅助文件（`assets/yt-dlp-zipimport`、`assets/cacert.pem`）
作为 extras 复制进每个实例。Fluixa 应用在自己的 bundle 内携带相同文件
（字节一致、SHA-256 相同）并传给 installer —— Catalog 本身保持纯元数据。

## 当前状态

| kind | version | platform-arch | 状态 |
|---|---|---|---|
| python | 3.11.10 | darwin-x86_64 | **已发布，端到端验证通过** |
| python | 3.11.10 | darwin-aarch64 / windows-x86_64 / linux-* | 尚未构建 |
| node | — | — | 仅协议预留，无条目 |

`python@3.11.10:darwin-x86_64` 的下载源（按序 fallback）：

1. GitHub release `fluixa/fluixa-runtimes` `python-3.11.10` — **已发布**
2. Gitee 镜像 — **已发布**（Gitee 会把资产名中的 `+` 归一化为空格；
   Catalog URL 使用实际文件名，`%20` 编码 —— 见 docs/release.zh-CN.md）
3. 上游 `astral-sh/python-build-standalone` `20241016` — **同字节 fallback 源**

三个源均验证字节一致：SHA-256（`575b49a7…`）是 artifact 的字节身份
（镜像改名也包含在内）。`verify_catalog.py --check-urls` 会探测全部源；
未发布的源会以 WARN 报告。

## 安全不变量

- 同一条目 `urls[]` 的每个源必须提供**相同字节** —— 所有镜像共用一个
  `sha256`；校验不匹配直接中止安装（绝不"绕过"镜像）。
- `size` + `sha256` 始终从真实 artifact 字节实测（`gen_catalog.py`），
  绝不手填。
- Catalog 是纯元数据：不能改变运行时 `kind`、不能执行任何程序、
  不能绕过校验。
- Schema 版本确定性：`spec_version != 1` 在消费端是硬解析失败。

## 兼容性

`catalog.json` 面向 `fluixa` `crates/runtime-store` **CATALOG_SPEC_VERSION
= 1**（RTS-V1.1）。Schema 变更必须升版本 + 记录迁移方案；消费端对更高
版本确定性拒绝，绝不猜测。

## 文档索引

English:

- Release Guide — [docs/release.md](./docs/release.md)
- Catalog V1 — [docs/catalog-v1.md](./docs/catalog-v1.md)
- Verification Records — [docs/verification-2026-09-20.md](./docs/verification-2026-09-20.md)

简体中文：

- Release 发布指南 — [docs/release.zh-CN.md](./docs/release.zh-CN.md)
- Catalog V1 规范 — [docs/catalog-v1.zh-CN.md](./docs/catalog-v1.zh-CN.md)
- Verification 验证记录 — [docs/verification-2026-09-20.md](./docs/verification-2026-09-20.md)（英文）

License: [LICENSE](./LICENSE).
