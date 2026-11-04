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
