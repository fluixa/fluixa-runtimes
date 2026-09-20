# Release 发布指南（简体中文 Runbook）

> English version: [release.md](./release.md)

本文是 fluixa-runtimes 的发布 Runbook，完整记录 `python-3.11.10` 首次
发布**实际走通**的每一步。仓库地址：

```text
GitHub: fluixa/fluixa-runtimes
Gitee:  fluixa/fluixa-runtimes
```

## 1. 发布前检查

```bash
python3 scripts/verify_catalog.py --fetch
python3 scripts/verify_catalog.py --upstream
```

两个命令分别做什么：

- `--fetch` —— 本地 `artifacts/<kind>/<version>/` 缺失 artifact 时，按
  catalog `urls[]` 顺序（primary → mirror → 上游）用 curl 下载（走
  `ALL_PROXY`/`https_proxy`），然后对每个条目校验**本地文件实测
  size + SHA-256 与 catalog 完全一致**。
- `--upstream` —— 对来源为 python-build-standalone（PBS）的条目，从
  上游 release 拉取**官方 `SHA256SUMS`**，逐字比对 artifact 的 SHA-256。
  这是独立于我们自身记录的第三方交叉证据。
- **SHA-256** 是 Runtime Artifact 的字节身份：所有镜像必须同字节，
  任何 mismatch 都直接失败，绝不绕过。
- `checksums/SHA256SUMS` —— 仓库内入库的指纹清单（`shasum -c` 兼容），
  覆盖 `artifacts/` + `assets/` 全部文件，由 `gen_catalog.py --update`
  生成；校验时会与本地文件逐个重算比对。

预期输出（`0 fail`）：

```text
PASS: … ok, 0 warn, 0 fail
```

## 2. macOS 安装 GitHub CLI

本机无 `gh` 时，从 GitHub CLI Releases 安装（本次实际采用的方法）：

```text
https://github.com/cli/cli/releases
```

本次实际使用：

```text
GitHub CLI 2.101.0
macOS amd64
```

> 注意：请按本机架构选择安装包（Apple Silicon 选 macOS arm64；
> Intel 选 macOS amd64）。

下载并解压后：

```bash
sudo mv bin/gh /usr/local/bin/
sudo chmod +x /usr/local/bin/gh
gh --version
```

## 3. GitHub CLI 登录

```bash
gh auth login
```

交互选择：

```text
GitHub.com
HTTPS
Login with a web browser
```

然后：

1. 终端显示一次性设备验证码（8 位）。
2. 浏览器打开 GitHub 提供的设备登录页面。
3. 输入终端显示的验证码。
4. 完成 GitHub 登录。
5. 如果启用了 Authenticator / 2FA，完成二次验证。
6. 最后确认：

```bash
gh auth status
```

> 安全提示：不要在任何文档、issue、截图中记录真实验证码、账号、
> Token 或其他个人敏感信息。

## 4. 创建 Draft Release

```bash
cd /Users/xuping/project/git/fluixa/fluixa-runtimes
python3 scripts/verify_catalog.py --fetch
python3 scripts/verify_catalog.py --upstream
scripts/release.sh python-3.11.10
```

`release.sh` 的四个阶段：

```text
1/4 verify catalog        —— 发布门禁：--upstream 交叉校验 + 期望矩阵
                             （--expect python@3.11.10:darwin-x86_64），
                             任何 FAIL 都中止发布
2/4 collect release assets —— 按 tag（<kind>-<version>）收集该条目的
                             全部 artifact + assets/*，缺失即报错退出
3/4 checksums              —— gen_catalog.py 重算并生成 SHA256SUMS
4/4 GitHub draft release   —— gh release create -R fluixa/fluixa-runtimes
                             <tag> --draft …，附全部资产 + 指纹表 notes
```

**Draft Release 创建成功 ≠ 发布完成。** Draft 只是上传了资产、生成了
草稿，必须人工检查后再 Publish（见下一节）。

## 5. Draft Release 检查

打开 `https://github.com/fluixa/fluixa-runtimes/releases`，检查 Draft：

```text
Tag:
python-3.11.10
```

Release assets（应为三个）：

```text
cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz
cacert.pem
yt-dlp-zipimport
```

**Python artifact 的 canonical filename 必须严格保持：**

```text
cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz
```

不要为了 Gitee 提前改这个名字 —— Gitee 的改名行为由 Catalog URL 兼容
（见 §6），canonical 名字属于 GitHub / PBS / Catalog 三方共同事实。

逐项核对：

- 文件大小（python artifact = 18011078 bytes）
- SHA-256（`575b49a7aa64e97b06de605b7e947033bf2310b5bc5f9aedb9859d4745033d91`）
- Release Tag（`python-3.11.10`）
- Release Assets（三个文件齐全，notes 内指纹表正确）

确认无误后点击：

```text
Publish release
```

## 6. Gitee Mirror

在 Gitee 同名仓库创建发行版：

```text
Gitee:
fluixa/fluixa-runtimes
```

```text
发行版 tag:
python-3.11.10
```

上传与 GitHub 完全相同的三个本地文件（bytes 必须一致）。

**本次实际发现的 Gitee 行为（重要）** —— Gitee 会对资产文件名做
normalization，把 `+` 转为空格：

```text
+
↓
space
```

例如：

```text
上传名:   cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz
实际保存: cpython-3.11.10 20241016-x86_64-apple-darwin-install_only_stripped.tar.gz
URL 中表现为: %20
```

即 `https://gitee.com/fluixa/fluixa-runtimes/releases/download/python-3.11.10/cpython-3.11.10%2020241016-x86_64-apple-darwin-install_only_stripped.tar.gz`
才是有效下载地址；用 `+` 原名访问会 404。

必须明确：

- **不是本地 Artifact 被修改** —— 本地文件字节不变。
- **GitHub canonical filename 不变**。
- **PBS upstream filename 不变**。
- **Catalog artifact filename 不变**（catalog 描述的 artifact 与本地
  canonical 文件一致）。
- **Gitee URL 使用实际 `%20` 文件名** —— 这是镜像侧 URL 适配，
  已写入 `catalog.json`。
- 下载后的 bytes 必须通过 size + SHA-256 验证。
- **SHA-256 才是 Runtime Artifact 的字节身份**，文件名只是元数据。

镜像完成后核对 Gitee 文件指纹：

```bash
curl -fsSL -o /tmp/gitee-check.tar.gz 'https://gitee.com/fluixa/fluixa-runtimes/releases/download/python-3.11.10/cpython-3.11.10%2020241016-x86_64-apple-darwin-install_only_stripped.tar.gz'
stat -f '%z' /tmp/gitee-check.tar.gz     # 18011078
shasum -a 256 /tmp/gitee-check.tar.gz    # 575b49a7…
```

## 7. 最终验证

```bash
python3 scripts/verify_catalog.py --check-urls
```

成功目标：

```text
PASS: ..., 0 warn, 0 fail
```

本次实际成功验证结果：

```text
PASS: 7 ok, 0 warn, 0 fail
```

（GitHub / Gitee / pbs 三个源全部探测可达，本地 artifact 与
SHA256SUMS 一致。）

## 8. 常见问题（Troubleshooting）

### `gh: command not found`

按 §2 安装 GitHub CLI，并确认：

```bash
gh --version
```

### GitHub CLI 登录问题

```bash
gh auth login
gh auth status
```

### GitHub Release asset 404

依次检查：

- Release 是否已经 **Publish**（Draft 状态的资产不可下载）
- Tag 是否正确（`python-3.11.10`）
- Asset 是否已上传
- 文件名是否正确（canonical 名含 `+`，URL 中 `+` 需保持原样）

### Gitee Python artifact 404

检查 Gitee 是否发生了：

```text
+ → space
```

如果发生（必然发生，Gitee 平台行为）：Catalog 的 Gitee URL 应使用实际
`%20` 文件名，**而不是修改 canonical artifact filename**。

### `curl rc=28`

这是 URL probe **超时**（网络层面连不上/无响应），与 **HTTP 404**
（服务器明确回答"不存在"）是两回事：

- rc=28 → 网络探测超时（代理、防火墙、DNS 等）
- 404 → 网络通，但该路径无资源

不要把二者混为一谈；`verify_catalog.py` 也会分别报告。

### SHA-256 mismatch

这是**硬错误**：说明某个源的 bytes 与 Catalog 声明的身份不一致。

不能通过修改 Catalog、修改文件名或关闭校验来绕过。正确做法是排查该
源的 artifact 是否被篡改/损坏/传错文件，修复源头后重发。
