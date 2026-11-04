# FFmpeg Runtime — 来源链与校验记录

采集日期：2026-11-04（全部哈希与版本串为当日实测，采集环境见文末）。

## 分发产物

| 项 | 值 |
| --- | --- |
| 分发名 | `ffmpeg-128263-g9f9b9548583-x86_64-apple-darwin.tar.gz` |
| catalog version | `128263-g9f9b9548583` |
| SHA-256（发布归档） | `789a2bfe57a0ef5128511461b2884a42884bf37f0184676c7cf690b7b36f2d14` |
| 上游构建 | evermeet.cx tessus 静态构建（`https://evermeet.cx/ffmpeg/`，版本串 `N-128263-g9f9b9548583-tessus`） |
| 实测 `-version` | `ffmpeg version N-128263-g9f9b9548583-tessus https://evermeet.cx/ffmpeg/` |
| 实测 `ffprobe -version` | `ffprobe version N-128263-g9f9b9548583-tessus`（与 ffmpeg 同构建同目录，`RUNTIME_MANIFEST.json` entrypoints 成对） |

发布归档 SHA-256 已由 Runtime Installer 在 2026-11-04 的真实链路安装中独立校验
（`cargo test -p fluixa-runtime-store --test real_ffmpeg_e2e`，605s，GitHub primary）。

## 许可证

- **SPDX**: `GPL-3.0-or-later`（构建参数含 `--enable-gpl --enable-version3`，
  即 GPLv3 及以上；见 `BUILD_CONFIG.txt` configuration 行）。
- 许可证全文：`LICENSE-GPL-3.0.txt`（gnu.org 官方文本，674 行）。
- 上游源码树内 `COPYING.GPLv3` 与 gnu.org 文本仅第 4 行 FSF 网址不同
  （`<http://fsf.org/>` vs `<https://fsf.org/>`），为上游保留的历史文本，实质为同一许可证。
- 版权声明：`Copyright (c) 2000-2026 the FFmpeg developers`（-version 输出原文；
  完整作者/版权名单见上游源码树 `AUTHORS` / 各文件头）。

## 源码对应物（GPLv3 §6 义务履行材料）

| 项 | 值 |
| --- | --- |
| 匹配 commit | `9f9b9548583ff7fbd633a5e6debe057d391f162c`（二进制版本串缩写 `9f9b9548583` 的完整展开） |
| 源码包 | `FFmpeg-9f9b9548583.tar.gz`（GitHub `FFmpeg/FFmpeg/archive/<commit>.tar.gz`，2026-11-04 下载） |
| 源码包 SHA-256 | `b904aab9749880027c68bded28849b93fcb0b04bcba032039ec874a4cee34184` |
| 源码树 RELEASE | `8.0.git` |
| 对应性验证方法 | 解包目录名 `FFmpeg-9f9b9548583ff7fbd633a5e6debe057d391f162c/` 与二进制 `-version` 输出中的 commit 逐字符比对一致 |

**注意**：这是 FFmpeg 本体的源码对应物。构建还静态链接了大量第三方库（见 BUILD_CONFIG），
其中 x264 / x265 的**精确版本（commit）无法从二进制确证**——`-buildconf` 只给出
`--enable-libx264` / `--enable-libx265` 开关，不含库版本。因此：

- x264（GPL-2.0-or-later）、x265（GPL-2.0-or-later）等 GPL 库的源码对应物
  **状态：`LEGAL_REVIEW_REQUIRED`**（获取路径：用已记录的 BUILD_CONFIG 从源码重建并记录
  所用依赖 commit，或向 tessus 上游求证构建清单）。
- 在此完成前，`scripts/check-license-compliance.sh` 将 ffmpeg 整体报告为
  `LEGAL_REVIEW_REQUIRED`（而非 `BLOCKED`——FFmpeg 本体的义务材料已齐）。

## 构建参数

完整 `-version` / `-buildconf` 输出存于 `BUILD_CONFIG.txt`（2026-11-04 采集自实际分发的
二进制）。关键开关（原文摘录）：

```text
--enable-gpl --enable-version3 --enable-libx264 --enable-libx265
--enable-libopenh264 --enable-libxvid --enable-libxavs ... --disable-ffplay
--pkg-config-flags=--static
```

GPL 触发项包括但不限于：libx264、libx265、libxvid、libxavs、libvidstab（GPL 组件）；
另含大量 LGPL/BSD/MIT 类库（libvpx、libopus、libvorbis、libmp3lame、zimg 等），
逐库 SPDX 分类属法律审查范围（`LEGAL_REVIEW_REQUIRED`）。

## 架构边界声明（不可自动成立）

桌面端通过**独立进程** spawn 该 ffmpeg 二进制（`RuntimeStore` 实例 → `entrypoint`），
与主程序之间只有命令行/文件 I/O 边界。此为常见工程实践，但本仓库不声称该架构
自动构成 GPLv3 意义上的"分离作品"；该结论必须由法律审查确认（Task F 约束）。

## 采集环境

- macOS（darwin-x86_64），本地 Runtime Store
  `~/.fluixa/runtimes/ffmpeg/128263-g9f9b9548583/darwin-x86_64/`（官方 catalog 经
  Runtime Installer 安装，SHA-256 校验通过）。
- `-version` / `-buildconf` 由该实例内 `ffmpeg/bin/ffmpeg` 直接输出。
