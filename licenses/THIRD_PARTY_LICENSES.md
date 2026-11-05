# 第三方软件与资源清单（THIRD_PARTY LICENSES）

> fluixa-runtimes 分发内容所依赖/包含的第三方资源汇总。
> 机器可读版本：`manifest.json`。逐资源证据：各子目录 `SOURCE.md`。
> 本清单只记录**版权许可**；编解码**专利**风险单列于
> `ffmpeg/PATENT-NOTES.md`（专利 ≠ 许可证）。

## 汇总表

| 资源 | 版本 | 上游 | SPDX | 许可证全文 | 版权归属 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| ffmpeg（Runtime） | `128263-g9f9b9548583`（N-128263-g9f9b9548583-tessus） | evermeet.cx tessus 构建；源码 FFmpeg/FFmpeg commit `9f9b9548583ff7fbd633a5e6debe057d391f162c` | `GPL-3.0-or-later` | `ffmpeg/LICENSE-GPL-3.0.txt` | the FFmpeg developers | ⚠ 需法律审查¹²³ |
| ffmpeg（遗留 9.0.1，扩展内置副本来源，不在 catalog） | `9.0.1-tessus` | 同上 | `GPL-3.0-or-later` | `ffmpeg/LICENSE-GPL-3.0.txt` | the FFmpeg developers | ⚠ 需法律审查¹ |
| python（Runtime） | `3.11.10`（pbs `20241016`） | astral-sh/python-build-standalone → python/cpython | `PSF-2.0` | `python/LICENSE-PSF-2.0.txt` | Python Software Foundation | ⚠ 需法律审查⁴ |
| yt-dlp（zipapp，media-tools） | `2026.08.19` | yt-dlp/yt-dlp | `Unlicense` | `yt-dlp/LICENSE-Unlicense.txt` | 无（公有领域声明） | ⚠ 需法律审查⁵ |
| cacert.pem（shared-assets） | certifi `2026.7.22` | certifi/python-certifi（内容：Mozilla CA 包） | `MPL-2.0` | `cacert/LICENSE-MPL-2.0.txt` | Mozilla contributors / certifi | ✅ 材料齐备 |

### 审查项脚注

1. **FFmpeg 静态构建内的 GPL 库**：x264（`0.165.3223`/commit `0480cb05`）与
   x265（`4.2+37-b81f650e2`）**版本已实证、源码已归档**（Task G WS2，2026-11-04，
   证据：构建者官方库版本表 + 归档内 COPYING=GPLv2）；剩余 GPL 库
   （xvid/xavs/vidstab/rubberband）版本已实证、源码未归档。完整 43 项依赖清单见
   `manifest.json` ffmpeg 条目 `dependencies`。
2. **GPL 架构隔离**：桌面端以独立进程调用 ffmpeg，但"进程边界=分离作品"的结论
   必须由法律审查确认，本仓库不自动主张。
3. **H.264/H.265 专利暴露**：x264/x265/openh264（源码静态编译，**不适用** Cisco
   预编译二进制的专利授权）均无专利授权；详见 `ffmpeg/PATENT-NOTES.md`。
   **使用侧核查（Task G WS1）**：产品实际 FFmpeg 链路（GIF/截帧/trim=`-c copy`/
   图片/元数据）零 H.264/H.265 编码；录屏 H.264 由系统 VideoToolbox 编码（与
   ffmpeg 无关）——详见 fluixa `docs/runtime/native-encoder-evaluation.md`。
4. **python 发行版捆绑组件**（OpenSSL/libffi/expat/SQLite/xz/mpdecimal 等）逐组件
   SPDX 清单未完成。
5. **yt-dlp zipapp 打包依赖**（brotli/mutagen/pycryptodomex/websockets/certifi 等）
   实际打包清单未审计。

## 分发方式与义务履行

- **分发载体**：GitHub/Gitee Release 归档（`release.sh` 按 4 类收集：
  runtime 工件 / shared-assets / media-tools）+ 桌面端 Runtime Store / 扩展内置副本。
- **GPLv3 §6（对应源码）**：FFmpeg 本体 + x264 + x265 源码已归档
  （`ffmpeg/*.tar.gz`，commit 与二进制/构建者清单实证匹配）；剩余 GPL 库
  （xvid/xavs/vidstab/rubberband）未归档（脚注 1）——在此之前，
  **不得对外声称"完整履行了 GPLv3 对应源码义务"**。
- **MPL-2.0**：文件级 copyleft，随包附带许可证全文即满足基本义务；证书内容轮换时
  需同步更新清单。
- **Unlicense / PSF-2.0**：随包附带许可证全文。

## 更新纪律

任何资源字节变化（升级/重打包）必须：更新 `manifest.json` 的 sha256/版本 →
补充/更新对应 `SOURCE.md` 证据 → 运行 `scripts/check-license-compliance.sh` 通过。
