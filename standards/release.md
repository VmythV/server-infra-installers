# 发布规范

每个软件独立发布。

示例：

```text
https://k8s-install.example.cn/install.sh
https://k8s-install.example.cn/releases/k8s-installer-v1.0.0-linux-amd64.tar.gz
https://docker-install.example.cn/install.sh
```

发布包必须提供 `SHA256SUMS`，入口脚本必须校验下载包。
