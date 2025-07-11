# 使用更轻量的基础镜像，并指定构建阶段名称
FROM python:3.13-alpine AS builder

ARG NGINX_VER=1.27.4
ARG RTMP_VER=1.2.2

WORKDIR /app

# 复制 Pipfile 文件
COPY Pipfile* ./

# 【优化】删除 pipenv 安装逻辑，改为直接复制本地虚拟环境
COPY .venv /.venv

# 下载并解压 Nginx 源码（使用国内镜像加速）
# 下载并解压 Nginx-RTMP 模块
# 配置并编译 Nginx 及 RTMP 模块 已被删除

# 使用预构建的 Nginx 包（来自本地 docker/nginx-bin 目录）
COPY docker/nginx-bin/nginx-bin.tar.gz /tmp/nginx-bin.tar.gz
RUN mkdir -p /usr/local/nginx && \
    tar xzf /tmp/nginx-bin.tar.gz -C /usr/local/nginx && \
    rm /tmp/nginx-bin.tar.gz

# 第二阶段：最终运行环境
FROM python:3.13-alpine

ARG APP_WORKDIR=/iptv-api

ENV APP_WORKDIR=$APP_WORKDIR \
    APP_HOST="http://localhost" \
    APP_PORT=8000 \
    PATH="/.venv/bin:/usr/local/nginx/sbin:$PATH"

WORKDIR $APP_WORKDIR

# 复制项目文件和构建产物
COPY . $APP_WORKDIR
COPY --from=builder /.venv /.venv
COPY --from=builder /usr/local/nginx /usr/local/nginx

# 创建日志目录并配置软链接
RUN mkdir -p /var/log/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# 安装运行时依赖
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache ffmpeg pcre

# 暴露端口
EXPOSE $APP_PORT 8080 1935

# 复制相关文件到容器中
COPY entrypoint.sh /iptv-api-entrypoint.sh
COPY config /iptv-api-config
COPY nginx.conf /etc/nginx/nginx.conf
COPY stat.xsl /usr/local/nginx/html/stat.xsl

# 设置入口脚本
RUN chmod +x /iptv-api-entrypoint.sh
ENTRYPOINT ["/iptv-api-entrypoint.sh"]
