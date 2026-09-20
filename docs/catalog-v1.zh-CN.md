# Runtime Catalog V1 — Schema 规范（简体中文）

> English version: [catalog-v1.md](./catalog-v1.md)

消费方基线：`fluixa/crates/runtime-store` 的 `CATALOG_SPEC_VERSION = 1`
（RTS-V1.1）。本文与消费端语义一一对应；若两者不一致，以 Rust 代码为
准，并必须回修本文档。

## 文档结构

```json
{
  "spec_version": 1,
  "entries": [ { …CatalogEntry… } ]
}
```

| 字段 | 类型 | 规则 |
|---|---|---|
| `spec_version` | u32 | 必须为 `1`；其他值在消费端是确定性解析失败 |
| `entries` | 数组 | 可为空（消费端接受；本仓库保持 ≥ 1 条） |

## CatalogEntry

```json
{
  "kind": "python",
  "version": "3.11.10",
  "platform": "darwin",
  "arch": "x86_64",
  "size": 18011078,
  "sha256": "575b49a7aa64e97b06de605b7e947033bf2310b5bc5f9aedb9859d4745033d91",
  "urls": [
    "https://github.com/fluixa/fluixa-runtimes/releases/download/<tag>/<asset>",
    "https://gitee.com/fluixa/fluixa-runtimes/releases/download/<tag>/<asset-plus-encoded-as-%20>",
    "https://github.com/astral-sh/python-build-standalone/releases/download/20241016/<asset>"
  ],
  "entrypoints": {
    "interpreter": "python/bin/python3.11",
    "tool": "yt-dlp"
  },
  "ca_bundle": "cacert.pem"
}
```

| 字段 | 类型 | 规则 |
|---|---|---|
| `kind` | string | 运行时家族（`python`，…）。非空。未来：`node`（仅协议预留，暂不发布条目） |
| `version` | string | 运行时版本。非空。对应 store 目录 `<kind>/<version>/<platform-arch>/` |
| `platform` | string | `darwin` / `windows` / `linux` |
| `arch` | string | `x86_64` / `aarch64` |
| `size` | u64 | 归档字节数，**从真实 artifact 实测**（`gen_catalog.py`）。下载后预检；`0` 表示跳过预检（SHA-256 始终是权威校验） |
| `sha256` | string | 归档的 64 位小写 hex。**所有镜像必须一致** —— mismatch 直接中止安装，绝不换下一个镜像重试 |
| `urls` | string[] | 有序下载源：primary → mirror1 → mirror2 → …；传输失败（网络/HTTP）换下一个源，**校验不匹配不换**。镜像必须提供字节一致的内容（SHA-256 钉死）；**文件名**仅允许文档化的镜像变换 —— Gitee 上传时会把 `+` 归一化为空格，因此其 Catalog URL 使用实际文件名（`%20` 编码） |
| `entrypoints` | map 名称→路径 | 相对实例目录的路径；原样写入 `RUNTIME_MANIFEST.json`；必须非空；installer 会赋予可执行位 |
| `ca_bundle` | string? | 相对实例目录的路径；存在时 resolver 注入 `SSL_CERT_FILE=<绝对路径>` |

**canonical artifact filename**（如
`cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz`）
是 GitHub / PBS / Catalog 共同的事实名，不因镜像改名而修改；镜像差异
只体现在对应镜像的 `catalog URL` / `mirror URL` 上，字节身份始终由
`SHA-256` + `size` 强制。

消费端未指定的字段会被忽略（serde 默认），但**本仓库禁止使用** ——
Catalog 保持纯元数据、schema 干净。

## 校验规则（消费端 + `verify_catalog.py` 共同强制）

1. `spec_version == 1`，否则确定性失败。
2. `kind` / `version` / `platform` / `arch` 非空。
3. `sha256` = 64 位 hex。
4. `urls` 非空；`entrypoints` 非空。
5. 不允许重复的 `(kind, version, platform, arch)`。
6. 本仓库约定：`python` 条目必须包含 `interpreter` + `tool` entrypoints
   以及 `ca_bundle`。

## Python 布局约定（pbs `install_only`）

python artifact 是上游 `python-build-standalone` 的
`install_only_stripped` tarball：归档顶层目录 `python/` 被保留在实例内，
因此：

- 实例根 = `<store>/python/<version>/<platform-arch>/`
- interpreter = `<实例>/python/bin/python3.11`
- extras（安装时从应用提供的文件复制）：
  `<实例>/yt-dlp`（可执行 zipapp）、`<实例>/cacert.pem`

## 新增条目清单

```sh
# 1. 把真实归档放到
#    artifacts/<kind>/<version>/<asset-name>   （asset 名 = urls basename）
# 2. 在 catalog.json 加入条目，size/sha256 先填 0/占位
# 3. python3 scripts/gen_catalog.py --update     # 实测字节，重生成 SHA256SUMS
# 4. python3 scripts/verify_catalog.py --upstream --check-urls
# 5. 新版本家族时补充 docs/release.md
```

`kind=node` 扩展：结构完全相同；`entrypoints` 形如
`{"bin": "node/bin/node"}`。Schema 无其他变化 —— 在真实 artifact 存在
之前**不要**发布 node 条目。
