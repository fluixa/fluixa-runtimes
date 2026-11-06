# FFmpeg LGPL-only Runtime — 第三方依赖清单（Task H）

> 构建采用 `--disable-autodetect` + 显式白名单，最终二进制中**实际启用的
> 第三方组件仅以下 3 项**（其余全部为 FFmpeg 内置实现，由 FFmpeg 自身
> LGPL-2.1-or-later 许可覆盖）。反向证明见 `proof/`（buildconf/encoders 等
> 8 项全量输出）。

## 依赖清单

| # | 依赖 | 版本 | 许可证 (SPDX) | source_availability | distribution_obligations | patent_review | verification_status |
|---|---|---|---|---|---|---|---|
| 1 | FFmpeg 本体 | 8.0.git（commit `9f9b9548583ff7fbd633a5e6debe057d391f162c`） | LGPL-2.1-or-later | archived: `FFmpeg-9f9b9548583.tar.gz`（同 commit 共享） | 随分发附 LGPL 全文 + 对应源码 | 编解码器实现级专利（H.264/HEVC 解码、编码走系统 VT）见 PATENT-NOTES | VERIFIED |
| 2 | zlib | macOS 系统 1.2.12（`/usr/lib/libz.1.dylib`） | Zlib | 系统组件（macOS 自带，随 OS 分发） | 无（系统库） | NONE-IDENTIFIED | VERIFIED |
| 3 | VideoToolbox / CoreMedia / CoreVideo / CoreFoundation / CoreServices（系统框架） | macOS 系统 | Apple 系统组件 | 系统组件 | 无（系统框架动态链接） | **REQUIRED**：H.264/HEVC **编码**经系统 VideoToolbox 执行（`h264_videotoolbox`/`hevc_videotoolbox`）——编码器由 OS 提供，专利责任模型与内置编码器不同，须法律审查确认 | VERIFIED（链接关系）|
| 4 | libwebp | 1.6.0 | BSD-3-Clause | archived: `libwebp-1.6.0.tar.gz`（sha256 `e4ab7009…`，静态链入） | 随分发附 BSD notice（LGPL 静态链接不触发 LGPL；BSD notice 保留） | NONE-IDENTIFIED | VERIFIED |

## GPL 排除证明（反向证明，2026-11-05）

| 组件 | 状态 | 证据 |
| --- | --- | --- |
| `--enable-gpl` | **ABSENT** | buildconf.txt 无该标志；configure 输出 `License: LGPL version 2.1 or later` |
| `--enable-nonfree` | **ABSENT** | 同上 |
| libx264 | **ABSENT** | buildconf 无 `--enable-libx264`；encoders.txt 无 libx264；`-c:v libx264` → Unknown encoder（exit 8） |
| libx265 | **ABSENT** | 同上（x265 编码器缺席） |
| libxvid | **ABSENT** | buildconf |
| libxavs | **ABSENT** | buildconf |
| libvidstab | **ABSENT** | buildconf + filters.txt 无 vidstab 滤镜 |
| librubberband | **ABSENT** | buildconf |
| libgsm（GPL 争议变体） | **ABSENT**（外部库未链接；FFmpeg 内置 gsm 解码器为 FFmpeg 自有实现，LGPL 覆盖） | buildconf |
| 其他 GPL 组件 | **ABSENT** | `--disable-autodetect` 下无任何未显式白名单的外部库可进入链接 |

## 源码对应关系

- FFmpeg：`FFmpeg-9f9b9548583.tar.gz`（commit 与版本串实证匹配，
  本 LGPL 构建与 GPL 构建同源）。
- libwebp：`libwebp-1.6.0.tar.gz`（sha256 在册，静态链入二进制——**对应源码
  必须随 LGPL 分发提供**，已归档）。

## 义务摘要

- **LGPL-2.1-or-later**：分发时提供 FFmpeg 源码（或书面提供渠道）+ LGPL 全文；
  用户可替换库（本构建 ffmpeg/ffprobe 为独立可执行文件，满足替换性要求）。
- **BSD-3-Clause（libwebp）**：随包附 notice；源码归档在册。
- **系统组件**：无再分发义务（随 OS）。
- **不要声称**：本清单为材料齐备证明，不等于法律审查通过（`LEGAL_REVIEW_REQUIRED`
  事项见 PATENT-NOTES.md 与 fluixa docs/legal/）。
