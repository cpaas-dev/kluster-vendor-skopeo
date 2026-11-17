## 发布流程

发布 = 一个多架构镜像 + 一个 GitHub Release，由 GitHub Actions 完成。

- 镜像：`ghcr.io/cpaas-dev/kluster-vendor-skopeo:<版本>`
- Release：tag 与上游版本号一致，notes 里只有一个版本号，不放别的内容

## Tag 规则

`vX.Y.Z` 是一个 manifest list，同时含 `linux/amd64` 与 `linux/arm64`。

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-skopeo:v1.25.2
docker buildx imagetools inspect ghcr.io/cpaas-dev/kluster-vendor-skopeo:v1.25.2
```

## 定时扫描（自动）

`.github/workflows/scan-upstream.yml` 每天 3 次（北京时间 10:37 / 18:37 / 02:37）
扫描 <https://github.com/containers/skopeo> 的 Release：

- 取上游最近 5 个正式 release（由 `TRACKED_RELEASES` 控制），按发布时间倒序，不按 minor 分组
- 排除 `draft` / `prerelease`，并要求 tag 严格匹配 `vX.Y.Z`，所以 `rc` / `alpha` / `beta` 不会被构建
- 这 5 个里本仓库还没发过的，才进构建矩阵

skopeo 同时维护多个 minor 分支（如 1.22 / 1.24 / 1.25），时常同期各发一个 patch，
这 5 个里通常会混着几个分支的版本，都会被构建。

## 手动补发

`.github/workflows/release.yml` 可以 `workflow_dispatch`，`versions` 填逗号分隔的版本
列表。已经有 Release 的版本会被跳过，不会覆盖。

## 调试

本地调试例子：

```bash
# 扫描未发布版本
GH_REPO=cpaas-dev/kluster-vendor-skopeo \
  .github/scripts/scan_upstream.bash

# 解析版本矩阵
GH_REPO=cpaas-dev/kluster-vendor-skopeo \
  VERSIONS=v1.25.2,v1.24.1 .github/scripts/resolve_versions.bash
```
