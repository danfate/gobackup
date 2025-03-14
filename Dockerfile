FROM joseluisq/mysql-client:latest

ARG VERSION=latest
ARG INFLUX_CLI_VERSION=2.7.5
ARG ETCD_VER="v3.5.11"



# 更新并安装所需软件包
RUN apt-get update && apt-get install -y \
  curl \
  ca-certificates \
  openssl \
  postgresql-client \
  libmariadb3 \
  # mysql-client \
  # mariadb-backup \
  redis-tools \
  # mongodb-org-tools \
  sqlite3 \
  tar \
  gzip \
  pigz \
  bzip2 \
  coreutils \
  lzip \
  xz-utils \
  lzop \
  zstd \
  libstdc++6 \
  icu-devtools \
  tzdata \
  wget \
  unzip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# 安装 sqlpackage
RUN wget https://aka.ms/sqlpackage-linux && \
    unzip sqlpackage-linux -d /opt/sqlpackage && \
    rm sqlpackage-linux && \
    chmod +x /opt/sqlpackage/sqlpackage

ENV PATH="${PATH}:/opt/sqlpackage"


# 安装 Influx CLI
RUN case "$(uname -m)" in \
      x86_64) arch=amd64 ;; \
      aarch64) arch=arm64 ;; \
      *) echo 'Unsupported architecture' && exit 1 ;; \
    esac && \
    curl -fLO "https://dl.influxdata.com/influxdb/releases/influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz" \
         -fLO "https://dl.influxdata.com/influxdb/releases/influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz.asc" && \
    tar xzf "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz" && \
    cp influx /usr/local/bin/influx && \
    rm -rf "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}" \
           "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz" \
           "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz.asc" \
           "influx" && \
    influx version

# 安装 etcdctl
RUN case "$(uname -m)" in \
      x86_64) arch=amd64 ;; \
      aarch64) arch=arm64 ;; \
      *) echo 'Unsupported architecture' && exit 1 ;; \
    esac && \
    curl -fLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${arch}.tar.gz" && \
    tar xzf "etcd-${ETCD_VER}-linux-${arch}.tar.gz" && \
    cp etcd-${ETCD_VER}-linux-${arch}/etcdctl /usr/local/bin/etcdctl && \
    rm -rf "etcd-${ETCD_VER}-linux-${arch}/etcdctl" "etcd-${ETCD_VER}-linux-${arch}.tar.gz" && \
    etcdctl version

# 复制并运行自定义安装脚本
ADD install /install
RUN /install ${VERSION} && rm /install

RUN { \
    sed -i 's/\[openssl_init\]/# [openssl_init]/' /etc/ssl/openssl.cnf && \
    printf "\n\n[openssl_init]\nssl_conf = ssl_sect" >> /etc/ssl/openssl.cnf && \
    printf "\n\n[ssl_sect]\nsystem_default = ssl_default_sect" >> /etc/ssl/openssl.cnf && \
    printf "\n\n[ssl_default_sect]\nMinProtocol = TLSv1\nCipherString = DEFAULT@SECLEVEL=0\n" >> /etc/ssl/openssl.cnf; \
}

CMD ["/usr/local/bin/gobackup", "run"]

