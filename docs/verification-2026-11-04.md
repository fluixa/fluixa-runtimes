# 验证记录 — Task F（2026-11-04）

> WS1（ffmpeg 实际使用闭环）+ WS2（离线导入全覆盖）+ WS3（licenses/ 合规体系）
> 在 fluixa-runtimes 仓库侧的交付与实测记录。fluixa 主仓库侧记录见
> fluixa `docs/work-log/latest.md`。按任务约束：未提交、未打 tag、未发布、未推送。

## WS1 — FFmpeg Runtime 实际使用闭环

- 官方 catalog（main）条目 `ffmpeg 128263-g9f9b9548583 darwin-x86_64`，
  经现有 Runtime Installer 真实链路安装到 `~/.fluixa/runtimes/`：
  `FLUIXA_RTS_E2E=1 FLUIXA_RTS_E2E_STORE=$HOME/.fluixa/runtimes cargo test
  -p fluixa-runtime-store --test real_ffmpeg_e2e` → **PASS**（605s，GitHub primary，
  SHA-256 `789a2bfe…` 校验通过，CURRENT.json 激活）。
- 二进制验证：`ffmpeg -version` / `ffprobe -version` → `N-128263-g9f9b9548583-tessus`
  同构建同目录配对；`--enable-gpl --enable-version3 --enable-libx264 --enable-libx265`。
- BUILD_CONFIG 全文已采集 → `licenses/ffmpeg/BUILD_CONFIG.txt`。
- 源码对应物：commit `9f9b9548583ff7fbd633a5e6debe057d391f162c` 源码包已归档
  （`licenses/ffmpeg/FFmpeg-9f9b9548583.tar.gz`，sha256 在 manifest.json）。

## WS2 — 离线导入（fluixa 主仓库代码，验证涉及两仓库资源）

- 真实资源包构建：官方 catalog + 两份官方 Release 归档下载至 `/tmp/fluixa-offline-bundle`
  （哈希与 catalog 逐一比对一致）。
- 真实导入 e2e（空库 → python+ffmpeg 全部 imported，extras sha256 溯源，
  yt-dlp 2026.08.19 与 ffmpeg 实际运行）→ `real_offline_import_full_bundle_e2e` PASS。
- 过程中修复 fluixa 主仓库真实缺陷：`runtime_provision.rs::workspace_root()`
  指向 `apps/` 而非仓库根，dev 环境 `provision_assets` 恒失败（python 已装时被掩盖），
  会使离线导入 python 条目缺 extras。已修复 + 测试。

## WS3 — licenses/ 合规体系（本仓库新增）

```text
licenses/                         # 全部新增
├── README.md                     # 原则 + 状态机 + 更新流程
├── THIRD_PARTY_LICENSES.md       # 人类可读汇总（5 资源 + 审查脚注）
├── manifest.json                 # 机器可读清单（哈希/SPDX/来源/审查项）
├── ffmpeg/  SOURCE.md + PATENT-NOTES.md + BUILD_CONFIG.txt
│            + LICENSE-GPL-3.0.txt + FFmpeg-9f9b9548583.tar.gz
├── python/  SOURCE.md + LICENSE-PSF-2.0.txt（v3.11.10 tag 精确对应）
├── yt-dlp/  SOURCE.md + LICENSE-Unlicense.txt
└── cacert/  SOURCE.md + LICENSE-MPL-2.0.txt + certifi-LICENSE-notice.txt
scripts/check-license-compliance.sh   # 状态机检查（exit 0；REVW 项如实保留）
scripts/tests/test_license_compliance.sh
```

关键事实（全部实测，非推测）：

- FFmpeg：GPLv3（`--enable-gpl --enable-version3`）；源码树 `COPYING.GPLv3` 与
  gnu.org 文本仅 FSF 网址一行之差（上游保留历史文本）。
- x264/x265 精确版本无法从二进制确证 → `LEGAL_REVIEW_REQUIRED`（不虚构）。
- 专利独立成文：openh264 为源码静态编译，**不适用** Cisco 预编译二进制的专利授权。
- yt-dlp `2026.08.19`、certifi `2026.7.22`（README 在册 + 实测版本输出）。
- `ffmpeg 9.0.1` 遗留产物（扩展内置副本来源）一并纳入清单（`ffmpeg-legacy-9.0.1`）。

## 测试结果

| 套件 | 结果 |
| --- | --- |
| `scripts/tests/test_license_compliance.sh` | **7/7**（正路径 + 篡改/缺失/审查项/catalog 缺口负路径） |
| `check-license-compliance.sh`（真实仓库） | 15 ok / 0 fail / 0 blocked / 4 review-required，EXIT=0 |
| fluixa 侧回归 | runtime-store 39 tests + desktop media 17 tests 全绿（见 fluixa work-log） |

## 未做（按约束）

- 不提交、不打 tag、不创建 Release、不推送；不重建任何已发布工件。
- GUI 人工验收（横幅/预览页交互）保持 PENDING，见 fluixa
  `docs/manual-testing/ffmpeg-shared-runtime.md` 与
  `docs/manual-testing/offline-import-and-licenses.md`。

---

# Task G 追加记录（2026-11-04，同日收尾）

## WS2 — FFmpeg 依赖取证升级

- **版本来源实证**：构建者（evermeet/tessus）官方库版本表快照已归档
  （`licenses/ffmpeg/evermeet-ffmpeg-build-info-2026-10-31.html`，编译日期
  2026-10-31；configuration 行与分发二进制 `-buildconf` 逐字符吻合）。
- **x264 = `0.165.3223`（commit `0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee`，
  git ls-remote 解析且 = master HEAD）**；源码归档 `x264-0480cb05.tar.gz`
  （sha256 `d0967a13…`），归档内 COPYING = GPLv2。
- **x265 = `4.2+37-b81f650e2`**；源码归档 `x265-b81f650e2.tar.gz`
  （sha256 `540de59b…`），归档内 COPYING = GPLv2。
- **43 项依赖清单**写入 `manifest.json` ffmpeg 条目 `dependencies`
  （name/version/source/license/source_availability/distribution_obligations/
  patent_review/verification_status；VERIFIED 为主，avisynth 变体、gsm、mysofa、
  vmaf 模型条款、zimg WTFPL、modplug 混合、iconv/orc/uuid 链接性 = REVIEW_REQUIRED）。
- 剩余 GPL 库（xvid/xavs/vidstab/rubberband）版本 VERIFIED、源码未归档 →
  ffmpeg 整体维持 `LEGAL_REVIEW_REQUIRED`（合规脚本 18 ok / 0 fail / 0 blocked / 4 review）。

## 未做（按约束）

- 不重建 ffmpeg（x264/x265 移除需新版本构建，属下游 Release 计划）；
  不动任何已发布工件与 Release。


---

# Task H 记录（2026-11-05）：LGPL-only FFmpeg Runtime

## 构建

- 源码：`licenses/ffmpeg/FFmpeg-9f9b9548583.tar.gz`（与 GPL 构建同 commit
  `9f9b9548583ff7fbd633a5e6debe057d391f162c`，来源对应性共享）。
- 配置：`--disable-gpl --disable-nonfree --disable-autodetect --disable-network
  --disable-ffplay --disable-x86asm --enable-static --disable-shared
  --enable-zlib --enable-videotoolbox --enable-libwebp --extra-version=fluixa-lgpl`。
- libwebp 1.6.0（BSD-3）静态编译链入（sha256 在册）。
- 产物：`artifacts/ffmpeg/128263-g9f9b9548583-lgpl/…tar.gz`（sha256
  `d64d3ead…`，21,978,049 字节，`ffmpeg/bin/{ffmpeg,ffprobe}` 布局与官方一致，
  自包含：仅系统 dylib + 系统框架）。

## 反向证明与功能回归（全部真实二进制）

- `licenses/ffmpeg-lgpl/proof/`：8 项能力输出全量存档；GPL 标志与 7 个 GPL 库
  全部 ABSENT；configure 判定 `License: LGPL version 2.1 or later`。
- 功能 10/10 PASS：ffprobe(mp4/mov/gif)、trim(-c copy)、GIF(palette)、PNG/JPEG、
  WebP、stream-copy 合流、VideoToolbox H264(-allow_sw)/HEVC、MOV、
  libx264 显式失败。

## 集成

- `catalog.json` ffmpeg 条目 → `128263-g9f9b9548583-lgpl`（旧 GPL 工件/资料
  保留）；`test_release_assets.sh` pin 更新（8/8 PASS）；合规脚本 catalog 映射
  支持跨资源条目匹配（22 ok / 0 fail / 0 blocked / 5 review）。
- fluixa 侧 E2E：`real_ffmpeg_lgpl_e2e.rs` PASS —— 真实 Store 安装→激活→解析→
  二进制反向证明→**GPL 旧实例共存断言**。
- 独立合规材料：`licenses/ffmpeg-lgpl/`（SOURCE/THIRD_PARTY_LICENSES/manifest/
  PATENT-NOTES/LICENSE-LGPL-2.1/libwebp 源码/proof）。

## 门禁

**RELEASE_CANDIDATE**（darwin-x86_64）。剩余：Release tag/发布（owner）、
codesign+notarization、专利与 GPL 隔离法律审查、Windows/Linux 工件（PENDING）。
