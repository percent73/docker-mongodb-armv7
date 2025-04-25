FROM debian:stable-slim as base

# 安装MongoDB构建依赖
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    build-essential ca-certificates \
    python3-full python3-pip python3-dev \
    git \
    cmake \
    curl \
    libssl-dev \
    libsasl2-dev libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 配置构建参数（根据架构调整）
ARG MONGO_VERSION=6.0.22
ARG MONGO_REPO=https://github.com/mongodb/mongo.git

# 克隆源码（使用浅克隆加速构建）
WORKDIR /build
RUN git clone --depth 1 -b r${MONGO_VERSION} ${MONGO_REPO} .

# 执行构建
RUN python3 -m venv buildenv && . buildenv/bin/activate && \
    python3 -m pip install -r etc/pip/compile-requirements.txt && \
    python3 buildscripts/scons.py DESTDIR=/usr/local install-servers --disable-warnings-as-errors

# 最终镜像（最小化体积）
FROM debian:stable-slim

# 复制构建产物
COPY --from=base /usr/local/bin/mongod /usr/local/bin/
COPY --from=base /usr/local/bin/mongos /usr/local/bin/

# 配置运行时依赖
RUN addgroup -g 1001 -S mongodb && \
    adduser -S -D -H -u 1001 -h /data/db -s /sbin/nologin -G mongodb mongodb && \
    mkdir -p /data/db /data/configdb && \
    chown -R mongodb:mongodb /data

# 暴露端口和入口点
EXPOSE 27017
USER 1001
ENTRYPOINT ["mongod"]
CMD ["--bind_ip_all"]
