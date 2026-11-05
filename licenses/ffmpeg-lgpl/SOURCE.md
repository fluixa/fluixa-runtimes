# FFmpeg LGPL-only Runtime — 来源链与校验记录（Task H，2026-11-05）

> 与历史 GPL Runtime（`../ffmpeg/`，tessus 构建）**并行共存**；本文档只覆盖
> Fluixa 自建的 LGPL-only 构建。历史资料一字未动。

## 分发产物

| 项 | 值 |
| --- | --- |
| 版本号（catalog） | `128263-g9f9b9548583-lgpl` |
| 归档 | `artifacts/ffmpeg/128263-g9f9b9548583-lgpl/ffmpeg-128263-g9f9b9548583-lgpl-x86_64-apple-darwin.tar.gz` |
| 归档 SHA-256 | `d64d3ead85c39004e4a075510d5b09c0a669d6be60ee95ffdee28af19a97d06e` |
| 归档大小 | 21,978,049 字节 |
| 布局 | 与官方工件一致：`ffmpeg/bin/{ffmpeg,ffprobe}` |
| 二进制 SHA-256 | ffmpeg `516a7cdeb0fd8d5168b91226ccd8d6dc9d847cc74fd06ca6f0dc370dfafbe5b2` / ffprobe `9954a776d5bcbcf058fbebe4e015058cca9860606a4efc5f41950e50166c5c83` |
| 版本串 | `8.0.git-fluixa-lgpl`（`--extra-version=fluixa-lgpl` 便于二进制身份识别） |
| 自包含性 | 静态链接（仅系统 dylib：libSystem/libz + VideoToolbox/CoreMedia 等系统框架；零第三方动态依赖） |
| 签名 | 未签名 —— 发布前需 owner 执行 codesign + notarization（发布步骤，非构建缺陷） |

## 构建来源链（完美对应）

1. **源码**：`../ffmpeg/FFmpeg-9f9b9548583.tar.gz`（与历史 GPL Runtime **同一 commit**
   `9f9b9548583ff7fbd633a5e6debe057d391f162c`，sha256 已在册）——源码对应关系与
   GPL 构建共享同一上游快照。
2. **配置**（全文见 `BUILD_CONFIG.txt`，configure 输出与 `-buildconf` 逐字一致）：

```text
--disable-gpl --disable-nonfree --disable-autodetect   ← 许可证核心开关
--enable-zlib --enable-videotoolbox --enable-libwebp    ← 显式白名单
--disable-network --disable-ffplay --disable-x86asm    ← 收缩面/无 nasm 环境
--enable-static --disable-shared --pkg-config-flags=--static
--extra-version=fluixa-lgpl
```

3. **`--disable-autodetect`**：configure 不会自动探测任何系统库——**不可能意外
   链入 GPL 组件**；只允许显式白名单。
4. **License 判定（configure 原文）**：`License: LGPL version 2.1 or later`。

## 第三方依赖（全部 3 项，无 GPL）

| 依赖 | 版本 | 许可证 | 来源 | SHA-256 |
| --- | --- | --- | --- | --- |
| zlib（系统 dylib） | macOS 1.2.12 | zlib | 系统自带 | —（系统组件） |
| VideoToolbox/CoreMedia/CoreVideo 等系统框架 | macOS 系统 | Apple 系统组件 | 系统自带 | — |
| libwebp | 1.6.0 | BSD-3-Clause | `storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz` | `e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564`（源码归档在本目录） |

**其余全部为 FFmpeg 内置实现**（gif/png/mjpeg 编码器、h264/hevc/vp9/aac/mp3
解码器、palettegen/paletteuse/scale/fps 等滤镜、mp4/mov 封装）——FFmpeg 自身
LGPL 许可覆盖。构建环境无 nasm → `--disable-x86asm`（纯 C，无性能敏感场景）。

## 反向证明（proof/ 目录，2026-11-05 实测）

| 证据 | 文件 | 结论 |
| --- | --- | --- |
| version | `proof/version.txt` | `8.0.git-fluixa-lgpl`，configuration 行含 `--disable-gpl --disable-nonfree` |
| buildconf | `proof/buildconf.txt` | **GPL/nonfree 标志 grep 缺席**；libx264/libx265/libxvid/libxavs/libvidstab/librubberband/libgsm **全部 ABSENT** |
| encoders | `proof/encoders.txt` | 含 gif/h264_videotoolbox/hevc_videotoolbox/mjpeg/png/libwebp_anim；**无 libx264** |
| 其余 | decoders/filters/muxers/demuxers/protocols | 能力白名单全量存档 |
| 功能回归 | `proof/functional/` | ffprobe/trim(-c copy)/GIF(palette)/PNG/JPEG/WebP/合流(copy)/MOV/VideoToolbox H264+HEVC 全 PASS；`-c:v libx264` → `Unknown encoder 'libx264'`（exit 8，显式失败） |

## 与历史 GPL Runtime 的共存

- 历史 GPL 资料：`../ffmpeg/`（源码/BUILD_CONFIG/SOURCE/PATENT-NOTES/x264/x265
  归档）**未移动、未删除、未覆盖**。
- 历史 GPL 工件：`artifacts/ffmpeg/128263-g9f9b9548583/`、`artifacts/ffmpeg/9.0.1/`
  保留；已发布 Release 不受影响。
- Store 共存：两个版本可同时安装于 Runtime Store，由 CURRENT.json/版本解析决定
  使用哪个；catalog 中 ffmpeg 条目已指向 LGPL 版本（推荐），GPL 版本从 catalog
  移除但工件与义务材料完整保留。
