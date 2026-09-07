# Alpine MTProto 一键部署

适用于没有 Docker 权限的 Alpine Linux VPS，使用静态 Go 版 `mtg` 部署 Telegram MTProto。

## 使用前配置
vps服务商如果默认没有配置ssh的22端口映射到公网端口，需要去它官网先配置一下，公网端口A->22，然后用 
```text
ssh -p 公网端口A root@公网ipv4
```
回车后输入管理面板中的密码就可以ssh连接上vps了
之后再配置一个公网端口B映射8443，以后用来连接到mtproto的

```text
公网端口B -> 8443
```

例如：

```text
54319 -> 8443
```

## 一条命令部署

直接传入公网端口，一条命令完成部署：

```sh
wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh -s -- 54319
```

将 `54319` 改成服务商实际分配的公网端口。由于公网端口映射配置在服务商面板中，VPS 内的脚本无法自动知道这个端口，因此必须通过参数或环境变量传入。

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
TLS_DOMAIN=cloudflare.com \
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | PUBLIC_PORT=54319 sh
```

无法自动获取公网 IP 时：

```sh
PUBLIC_IP=156.245.244.165 \
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh -s -- 54319
```

重新生成 Secret：

```sh
REGENERATE_SECRET=1 \
  wget -qO- https://raw.githubusercontent.com/ZinhoYip/ulzix-mtproto-scripts/main/install.sh | sh -s -- 54319
```

## 常用检查

```sh
ps aux | grep '[m]tg run'
cat /home/mtproxy/mtg.log
```

公网端口必须始终填写服务商实际分配的端口，不能把公网端口误填成内网 `8443`。
