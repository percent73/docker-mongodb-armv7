FROM debian:stable-slim as base

# 安装MongoDB构建依赖
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    scons build-essential ca-certificates \
    git \
    libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libboost-thread-dev \
    && rm -rf /var/lib/apt/lists/*

# 配置构建参数（根据架构调整）
ARG MONGO_VERSION=3.2.22
ARG MONGO_REPO=https://github.com/mongodb/mongo.git

# 克隆源码（使用浅克隆加速构建）
WORKDIR /build
RUN git clone --depth 1 -b r${MONGO_VERSION} ${MONGO_REPO} .

# 执行构建
RUN cd src/third_party/mozjs-38/ && \
    ./get_sources.sh && \
    ./gen-config.sh arm linux && \
    cd - && \
    scons mongo mongod --wiredtiger=off --mmapv1=on && \
    strip -s build/opt/mongo/mongo && strip -s build/opt/mongo/mongod

# 最终镜像（最小化体积）
FROM debian:stable-slim

# 复制构建产物
COPY --from=base /build/build/opt/mongo/mongod /usr/local/bin/
COPY --from=base /build/build/opt/mongo/mongo /usr/local/bin/

# 配置运行时依赖
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    tini tzdata gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
    
RUN addgroup -g 1001 -S mongodb && \
    adduser -S -D -H -u 1001 -h /data/db -s /sbin/nologin -G mongodb mongodb && \
    mkdir -p /data/db /data/configdb && \
    chown -R mongodb:mongodb /data

# 暴露端口和入口点
EXPOSE 27017
USER 1001
ENTRYPOINT ["mongod"]
CMD ["--bind_ip_all"]
