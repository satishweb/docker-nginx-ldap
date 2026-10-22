FROM ubuntu:24.04
LABEL maintainer="Satish Gaikwad <satish@satishweb.com>"

ARG NGINX_VERSION=1.30.6
ARG LDAP_MODULE_COMMIT=241200eac8e4acae74d353291bd27f79e5ca3dc4

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gcc \
    git \
    libldap2-dev \
    libpcre2-dev \
    libssl-dev \
    make \
    wget \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# The nginx and the module for the authentication with a directory of ldap
# are made from the sources. The versions of them are fixed.
RUN mkdir -p /opt/src \
    && cd /opt/src \
    && git clone --quiet https://github.com/nginx/nginx.git \
    && cd nginx \
    && git checkout --quiet "release-${NGINX_VERSION}" \
    && git clone --quiet https://github.com/kvspb/nginx-auth-ldap.git /opt/src/nginx-auth-ldap \
    && cd /opt/src/nginx-auth-ldap \
    && git checkout --quiet "${LDAP_MODULE_COMMIT}" \
    && cd /opt/src/nginx \
    && ./auto/configure \
        --add-module=/opt/src/nginx-auth-ldap \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-pcre \
        --conf-path=/etc/nginx/nginx.conf \
        --sbin-path=/usr/sbin/nginx \
        --pid-path=/var/run/nginx.pid \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
    && make -j "$(nproc)" \
    && make install

# The programs that are only needed to make nginx are taken out of the image.
RUN apt-get purge -y \
        git \
        gcc \
        make \
        libpcre2-dev \
        libssl-dev \
        wget \
    && apt-get autoremove -y \
    && apt-get install -y --no-install-recommends \
        libldap2 \
        libpcre2-8-0 \
        libssl3t64 \
        zlib1g \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* /usr/src/* /tmp/* /usr/share/doc/* /usr/share/man/* /opt/src

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# The folder of the configuration of the sites, the configuration of the
# image includes it.
RUN mkdir -p /etc/nginx/conf.d

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
