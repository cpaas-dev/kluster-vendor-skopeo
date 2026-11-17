# kluster-vendor-skopeo

从上游 skopeo 源码静态编译，打包成一个多架构 OCI 镜像，用于离线 / 内网环境分发。

[![Release](https://github.com/cpaas-dev/kluster-vendor-skopeo/actions/workflows/release.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-skopeo/actions/workflows/release.yml)
[![Scan upstream](https://github.com/cpaas-dev/kluster-vendor-skopeo/actions/workflows/scan-upstream.yml/badge.svg)](https://github.com/cpaas-dev/kluster-vendor-skopeo/actions/workflows/scan-upstream.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-informational)

```bash
docker pull ghcr.io/cpaas-dev/kluster-vendor-skopeo:v1.25.2
```

## 这是什么

离线环境里搬运镜像需要 skopeo。上游 Release 只有源码，不发二进制，发行版的包又依赖
系统动态库。本仓库从上游 tag 的源码静态编译出单个二进制，按目标架构放进镜像。

## 镜像内容

```plain
/cpaas/vendor/skopeo/
├── skopeo                                 # 目标架构，静态链接
├── skopeo.sha256sum
└── policy.json                            # 上游 default-policy.json
```

下游校验和使用：

```bash
cd /cpaas/vendor/skopeo

sha256sum -c skopeo.sha256sum
./skopeo --policy policy.json copy docker-archive:img.tar oci:/data/oci:img
```

说明：

- 镜像 tag 和 Release 与上游 tag 1:1：`v1.25.2` → `v1.25.2`
- 源码取自上游 tag 的 GitHub 源码包，构建期会核对 `version/version.go` 和请求的版本一致
- 编译方式照上游 `install.md` 的 "Building a static binary"：`CGO_ENABLED=0`，
  build tag 为 `exclude_graphdriver_btrfs containers_image_openpgp`，
  依赖全部用源码自带的 `vendor/`，构建期不拉 Go 模块
- arm64 由 Go 交叉编译产出，不经过 QEMU
- 上游没有二进制，`skopeo.sha256sum` 是本仓库编译后自己算的，只能保证「镜像里的这个
  文件没被改过」
- 构建期会检查 ELF magic + `e_machine`、`CGO_ENABLED=0`，并在构建机同架构上跑
  `skopeo --version` 核对版本号
- 二进制不读 `/etc/containers/policy.json` 时需要 `--policy` 指定策略，所以一并带上
  上游的 `default-policy.json`（接受任意镜像，不校验签名）
- 只含目标架构。`linux/arm64` 的镜像里只有 arm64 的 skopeo

## 静态编译的限制

上游明确说明静态编译版本不受官方支持（见上游 `install.md`），已知限制：

- 签名用纯 Go 的 openpgp 实现，不支持依赖 gpgme 的功能
- 使用 Go 原生 DNS 解析，不支持 `.local`（mDNS）、LDAP 等通过 NSS 的名字解析
- 不含 btrfs 存储驱动

离线环境里在 registry、OCI 目录、docker-archive 之间搬运镜像不受影响。

## 文档

- [自定义构建](docs/BUILD_YOUR_OWN.md) —— build-args、下载加速、Go 镜像
- [发布流程](docs/RELEASE.md) —— tag 规则、定时扫描、本地调试脚本
- [贡献指南](docs/CONTRIBUTING.md)

## 相关仓库

- skopeo <https://github.com/containers/skopeo>

## 许可

本仓库的构建脚本以 Apache-2.0 发布。打包进镜像的上游产物遵循其原始许可：
skopeo（Apache-2.0）。二进制里静态编译进的 Go 依赖各自的许可见上游源码 `vendor/`。
