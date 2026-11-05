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

### x264 / x265 取证（Task G WS2，2026-11-04 升级为 VERIFIED）

版本来源：**构建者（tessus/evermeet）为本次构建发布的外部库版本表**
（`evermeet-ffmpeg-build-info-2026-10-31.html`，编译日期 2026-10-31；其
configuration 行与分发二进制 `-buildconf` 逐字符吻合，交叉验证成立）。
快照页与本构建一一对应（`ffmpeg-128263-g9f9b9548583`）。

| 项 | x264 | x265 |
| --- | --- | --- |
| 版本（构建者清单） | `0.165.3223`（`20250910-0480cb05`） | `4.2+37-b81f650e2`（`20260623-b81f650e2`） |
| 完整 commit | `0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee`（`git ls-remote` 解析，= master HEAD） | `b81f650e2…`（bitbucket 归档目录名 `multicoreware-x265_git-b81f650e21e8`） |
| 源码归档 | `x264-0480cb05.tar.gz`（sha256 `d0967a13…`） | `x265-b81f650e2.tar.gz`（sha256 `540de59b…`） |
| 许可证核验 | 归档内 `COPYING` = **GPLv2** | 归档内 `COPYING` = **GPLv2** |

> 归档内版本字符串（如 x264 `0.165.3223` 即 X264_BUILD 3223 / X264_POINTVER）
> 可在源码树 `version.sh`/`x264.h` 中复核；此为源码↔二进制的二次对应证据。

**剩余 GPL 触发项**：libxvid（1.3.7）、libxavs（20110821-r55）、libvidstab
（1.1.2-214）、librubberband（4.0.0）——版本已由构建者清单 **VERIFIED**，
源码归档未完成（`LEGAL_REVIEW_REQUIRED`，获取路径同上，公开上游可取）。

- 完整 43 项依赖清单（含版本/许可证/义务/专利/验证状态）见 `manifest.json`
  ffmpeg 条目 `dependencies` 数组。
- 在剩余 GPL 源码归档完成前，ffmpeg 整体仍报告 `LEGAL_REVIEW_REQUIRED`
  （非 `BLOCKED`——FFmpeg/x264/x265 义务材料已齐）。

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
