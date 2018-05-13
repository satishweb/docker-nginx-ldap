FROM ubuntu:xenial

MAINTAINER satish@satishweb.com

# Install required packages

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git \
        ca-certificates \
        gcc \
        make \
        libpcre3-dev \
        zlib1g-dev \
        libldap2-dev \
        libssl-dev \
        wget && \
    mkdir -p /var/log/nginx /etc/nginx /opt/src && \
    cd /opt/src && \
    git clone https://github.com/kvspb/nginx-auth-ldap.git && \
    git clone https://github.com/nginx/nginx.git && \
    git ls-remote --tags https://github.com/nginx/nginx.git | sort -rt '/' -k 3 -V|head -1|awk -F/ '{ print $3 }' > /opt/src/nginx.latest.version && \
    cd /opt/src/nginx && \
    git checkout tags/$(cat /opt/src/nginx.latest.version) && \
    ./auto/configure \
        --add-module=/opt/src/nginx-auth-ldap \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-pcre \
        --with-debug \
        --conf-path=/etc/nginx/nginx.conf \ 
        --sbin-path=/usr/sbin/nginx \ 
        --pid-path=/var/log/nginx/nginx.pid \ 
        --error-log-path=/var/log/nginx/error.log \ 
        --http-log-path=/var/log/nginx/access.log && \ 
    make install && \
    apt-get purge -y \
        git \
        gcc \
        make \
        libpcre3-dev \
        zlib1g-dev \
        libssl-dev \
        wget && \
    apt-get autoremove -y && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* /usr/src/* /tmp/* /usr/share/doc/* /usr/share/man/* /usr/share/locale/* /opt/src

# link logs to docker log collector.
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

ADD nginx.conf /etc/nginx/

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]