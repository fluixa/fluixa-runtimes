# FFmpeg LGPL-only Runtime — 专利风险备忘（独立于许可证）

> 版权许可证（LGPL）已通过构建配置确证；**专利是另一维度**，本文不重复版权内容。

## 与 GPL 构建的差异

| 维度 | GPL 构建（历史，tessus） | LGPL 构建（本 Runtime） |
| --- | --- | --- |
| H.264 编码实现 | x264（GPL 库，源码编译）| **系统 VideoToolbox**（`h264_videotoolbox`，Apple 提供） |
| H.265 编码实现 | x265 | **系统 VideoToolbox**（`hevc_videotoolbox`） |
| 编解码专利暴露 | 库实现直接编入分发二进制 | 编码由**用户机器上的 OS 框架**执行；分发物仅含调用 glue（FFmpeg 的 videotoolbox wrapper） |
| 内置解码器 | 同（h264/hevc/vp9 解码为 FFmpeg 内置实现，非 GPL 库） | 同（内置解码器保留，LGPL 许可覆盖版权维度） |

**要点**：LGPL-only 构建**不减少解码实现的专利暴露**（h264/hevc/vp9 解码仍在
FFmpeg 内置实现中）；它改变的是**编码**责任模型——编码由系统框架执行。
"用系统编码器 = 无专利问题"是**不可证明的结论**，是否成立取决于分发模式、
地区与 Apple 的授权安排，**必须由法律审查确认**（`LEGAL_REVIEW_REQUIRED`）。

## 逐项审查状态

| 项 | 状态 | 说明 |
| --- | --- | --- |
| H.264/HEVC/VP9 解码（FFmpeg 内置） | `LEGAL_REVIEW_REQUIRED` | 专利池对解码实现的主张因辖区而异 |
| H.264 编码（经 VideoToolbox） | `LEGAL_REVIEW_REQUIRED` | 编码发生在用户 OS 内；分发调用代码的责任边界需审查 |
| HEVC 编码（经 VideoToolbox） | `LEGAL_REVIEW_REQUIRED` | HEVC 专利池最复杂（多池重叠） |
| VP9/AV1 | 解码：VP9 有上游专利声明；AV1 有 AoM 专利许可生态（本构建未启用 libaom/dav1d，AV1 解码为 FFmpeg 内置） | 确认范围 |
| WebP/MJPEG/PNG/GIF | NONE-IDENTIFIED | 无已知活跃专利池 |

## 审查输入

1. `proof/buildconf.txt`（实际启用的全部能力）。
2. 本文件差异表（编码责任模型变化）。
3. fluixa `docs/runtime/native-encoder-evaluation.md`（使用矩阵：产品当前功能
   零 H.264/HEVC **编码**；录屏编码走应用自身的 AVFoundation 链路）。
