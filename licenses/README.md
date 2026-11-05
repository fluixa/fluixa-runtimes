# licenses/ — 第三方资源合规材料库

> Task F WS3 交付。本目录是 fluixa-runtimes 所分发资源的**许可证与来源合规材料的唯一存放点**。
> 原则（任务约束，逐条可审计）：
>
> 1. **不虚构**：只记录可验证事实。无法从产物中确证的信息（如 x264/x265 的精确版本号）
>    一律标注 `LEGAL_REVIEW_REQUIRED`，绝不猜测填充。
> 2. **全链路可溯源**：每个分发产物记录 upstream / version / SHA-256 / SPDX / 许可证全文 /
>    源码对应物（能取到的以真实文件落盘）。
> 3. **专利 ≠ 许可证**：H.264/H.265 等编解码专利风险与版权许可证**严格分离**
>    （见 `ffmpeg/PATENT-NOTES.md`），不存在"取得许可证即覆盖专利"的表述。
> 4. **GPL 架构隔离不可自动成立**：ffmpeg 为 GPLv3 构建，通过进程边界调用（桌面端以
>    独立进程 spawn ffmpeg）是被普遍采用的做法，但本仓库**不声称**这构成自动的
>    GPL 隔离/豁免；架构性结论必须由法律审查确认（`LEGAL_REVIEW_REQUIRED`）。

## 目录布局

```text
licenses/
├── README.md                     # 本文件：原则与布局
├── THIRD_PARTY_LICENSES.md       # 人类可读的第三方清单汇总
├── manifest.json                 # 机器可读清单（资源→许可证/哈希/来源/状态）
├── ffmpeg/
│   ├── BUILD_CONFIG.txt          # 实际分发二进制的 -version/-buildconf 全文（2026-11-04 采集）
│   ├── LICENSE-GPL-3.0.txt       # GPLv3 全文（gnu.org 官方文本）
│   ├── FFmpeg-9f9b9548583.tar.gz # 匹配 commit 的上游源码（对应物，真实落盘）
│   ├── x264-0480cb05.tar.gz      # x264 0.165.3223 匹配 commit 源码（Task G WS2 归档）
│   ├── x265-b81f650e2.tar.gz     # x265 4.2+37 匹配 commit 源码（Task G WS2 归档）
│   ├── evermeet-ffmpeg-build-info-2026-10-31.html # 构建者官方配置+库版本表（取证证据）
│   ├── SOURCE.md                 # 来源链与校验记录
│   └── PATENT-NOTES.md           # H.264/H.265/x264/x265 专利风险（独立于许可证）
├── ffmpeg-lgpl/                  # Task H：LGPL-only Runtime（与 ffmpeg/ 并行共存）
│   ├── BUILD_CONFIG.txt          # 新二进制 -version/-buildconf 全文
│   ├── LICENSE-LGPL-2.1.txt      # LGPL-2.1 官方全文（源码树 COPYING.LGPLv2.1）
│   ├── THIRD_PARTY_LICENSES.md   # 仅 4 项依赖（zlib/系统框架/libwebp/FFmpeg 本体）
│   ├── manifest.json             # 独立合规清单（GPL 排除证明/功能验证/审查项）
│   ├── SOURCE.md / PATENT-NOTES.md
│   ├── libwebp-1.6.0.tar.gz      # 静态链入的对应源码
│   └── proof/                    # 反向证明 8 项输出 + 功能回归产物
├── python/
│   ├── LICENSE-PSF-2.0.txt       # CPython v3.11.10 tag 的官方 LICENSE 全文
│   └── SOURCE.md                 # python-build-standalone 来源链
├── yt-dlp/
│   ├── LICENSE-Unlicense.txt     # yt-dlp 官方 LICENSE 全文（Unlicense）
│   └── SOURCE.md
└── cacert/
    ├── LICENSE-MPL-2.0.txt       # MPL-2.0 官方全文
    ├── certifi-LICENSE-notice.txt# certifi 上游 LICENSE（声明式包装）
    └── SOURCE.md
```

## 合规状态机（scripts/check-license-compliance.sh）

| 状态 | 判定条件 |
| --- | --- |
| `SOURCE_MATCH_VERIFIED` | 分发产物版本串 ↔ 源码对应物已实证匹配（当前仅 ffmpeg） |
| `HASH_VERIFIED` | 记录的 SHA-256 与本地产物字节一致 |
| `MATERIALS_PRESENT` | 许可证文本与来源材料齐备（不保证哈希已复核） |
| `LEGAL_REVIEW_REQUIRED` | 存在需要人工法律审查的未决事项（逐项列出） |
| `BLOCKED` | 缺失必要材料，无法进入审查 |

状态是**单调收敛**的检查结果而非资格证明：脚本输出的是"证据齐备程度"，
最终合规结论以法律审查为准。

## 更新流程（新增/升级资源时）

1. 采集新产物 `-version/-buildconf`（或等价版本信息）→ 存入对应资源目录。
2. 下载匹配版本的上游源码/许可证全文 → 落盘并计算 SHA-256。
3. 更新 `manifest.json` 与 `THIRD_PARTY_LICENSES.md`。
4. 运行 `scripts/check-license-compliance.sh`，确认无 `BLOCKED`；
   未决事项保持 `LEGAL_REVIEW_REQUIRED` 并在 PR 中明示。
