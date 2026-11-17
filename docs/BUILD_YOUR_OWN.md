## 打包

```bash
# 构建多架构镜像 amd64/arm64
docker buildx build --platform linux/amd64,linux/arm64 \
  -t xxx .
```

两个架构都在构建机上用 Go 交叉编译，不需要 QEMU。

## 指定版本

```bash
# 和上游 tag 一致，带 v 前缀
docker buildx build \
  --build-arg INST_SKOPEO_V=v1.25.2 \
  -t ...
```

## 下载加速

```bash
# 国内访问加速
docker buildx build \
  --build-arg GITHUB_URL=https://gh-proxy.org/https://github.com \
  -t ...

# 本地自建 Nexus 代理
docker buildx build \
  --build-arg GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github \
  -t ...
```

源码包地址是 `${GITHUB_URL}/containers/skopeo/archive/refs/tags/<版本>.tar.gz`，
镜像站要能代理这个路径。

## Go 镜像

```bash
# 编译用的 Go 镜像，版本要满足上游 go.mod 的要求（v1.25.2 要求 go 1.26.0+）
GOLANG_IMAGE=docker.io/library/golang:1.26
```

构建设置了 `GOTOOLCHAIN=local`，Go 版本不够时直接报错，不会去网上下载新的工具链。
要可复现，可以写成带 digest 的形式，例如 `docker.io/library/golang:1.26@sha256:...`。

## 其他 build-args

```bash
# 最终镜像的基础镜像
BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0

# 编译哪些架构，空格分隔。
# 最终镜像只装 TARGETARCH，这里改小只能省编译时间，改小于目标架构集合会构建失败
VENDOR_ARCHES="amd64 arm64"

# Go build tags，默认是上游静态编译的组合
SKOPEO_BUILDTAGS="exclude_graphdriver_btrfs containers_image_openpgp"
```
