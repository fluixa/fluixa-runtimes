# cacert.pem（CA 根证书包）— 来源链与校验记录

采集日期：2026-11-04。

## 分发产物

| 项 | 值 |
| --- | --- |
| 分发名 | `assets/cacert.pem`（shared-assets 类 Release 资产；作为 python 实例 extras 装入并经 `SSL_CERT_FILE` 注入） |
| SHA-256 | `9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f` |
| 上游 | [certifi/python-certifi](https://github.com/certifi/python-certifi) |
| 版本 | certifi `2026.7.22`（仓库 README 在册；与 `certifi-LICENSE-notice.txt` 描述的 ca-bundle.crt 改包一致） |
| 内容 | Mozilla CA Root Certificates 包（certifi 对 ca-bundle.crt 的改包） |

## 许可证

- **SPDX**: `MPL-2.0`（certifi 项目许可证；其内容源自 Mozilla NSS 的 CA 证书包）。
- 全文：`LICENSE-MPL-2.0.txt`（Mozilla 官方 MPL-2.0 文本，16726 字节）。
- 声明文件：`certifi-LICENSE-notice.txt`（certifi 仓库 LICENSE 原文——说明
  "modified version of ca-bundle.crt" 的归属声明）。
- 版权/归属：MPL-2.0 头部声明与 certifi notice；个别根证书的归属由
  Mozilla CCDB（包含清单内的各 CA 运营方）持有，按 MPL-2.0 分发。

## 边界与未决事项

1. 证书**内容本身**会随 Mozilla/上游更新而轮换；升级时必须同步更新本文件记录的
   SHA-256 与 certifi 版本号（`scripts/check-license-compliance.sh` 会拦截
   资产字节变化而清单未更新的情况）。
2. "分发包内嵌根证书"与"信任决策"是运维/安全议题，不属于本合规文件范围。
