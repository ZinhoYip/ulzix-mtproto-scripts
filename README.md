# Alpine MTProto 一键部署

适用于没有 Docker 权限的 Alpine Linux VPS，使用静态 Go 版 `mtg` 部署 Telegram MTProto。

## 使用前配置

先在 VPS 服务商面板建立端口映射：

```text
公网端口 -> 8443
```

例如：

```text
54319 -> 8443
```

## 一条命令部署

交互式输入公网端口：

```sh
wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh
```

直接传入公网端口，不需要交互：

```sh
wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh -s -- 54319
```

脚本会自动：

- 安装 Alpine 运行依赖
- 识别 `x86_64` 或 `aarch64`
- 下载静态编译的 `mtg`
- 自动获取公网 IPv4
- 生成并保存 TLS Secret
- 启动内网 `8443` 端口
- 配置 Alpine OpenRC 开机启动
- 输出 `tg://` 和 HTTPS 一键链接

Secret 保存在 `/home/mtproxy/mtg.secret`，重复执行脚本时默认复用，不会无故改变 Telegram 配置。

## 非默认配置

```sh
PUBLIC_PORT=54319 TLS_DOMAIN=cloudflare.com \
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh
```

无法自动获取公网 IP 时：

```sh
PUBLIC_IP=156.245.244.165 PUBLIC_PORT=54319 \
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh
```

重新生成 Secret：

```sh
REGENERATE_SECRET=1 PUBLIC_PORT=54319 \
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh
```

## 常用检查

```sh
ps aux | grep '[m]tg run'
cat /home/mtproxy/mtg.log
```

公网端口必须始终填写服务商实际分配的端口，不能把公网端口误填成内网 `8443`。
