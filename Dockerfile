ARG src_image=rocker/tidyverse
ARG src_image_tag=latest
ARG TINI_VERSION=v0.18.0
ARG GOSU_VERSION=1.11
ARG GOMPLATE_VERSION=3.1.0

FROM ${src_image}:${src_image_tag} AS base
RUN apt-get update -qq && \
    apt-get install -y \
    apache2 \
    libapache2-mod-auth-openidc \
    libapache2-mod-auth-cas \
    curl \
    apache2-dev \
    dh-autoreconf && \
    rm -rf /var/lib/apt/lists/* && \
    a2dissite '*' && \
    # Allow apache to run as normal user and redirect logs to stdout/stderr
    for x in log run lock; do mkdir -p /var/$x/apache2; done && \
    ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log && \
    for x in log run lock; do chmod -R a+rwX /var/$x/apache2; done && \
    echo 'options(shiny.port = 3838, shiny.host = "127.0.0.1")' >> /usr/local/lib/R/etc/Rprofile.site
RUN mkdir /build \
    && cd /build \
    && git clone https://github.com/apereo/mod_auth_cas \
    && cd mod_auth_cas \
    && autoreconf -ivf \
    && ./configure \
    && make \
    && make install
RUN rm -rf /build

FROM base AS build-env
ARG TINI_VERSION
ARG GOSU_VERSION
ARG GOMPLATE_VERSION
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /out/tini
RUN chmod +x /out/tini
ADD https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 /out/usr/local/bin/gosu
RUN chmod +x /out/usr/local/bin/gosu
ADD https://github.com/hairyhenderson/gomplate/releases/download/v${GOMPLATE_VERSION}/gomplate_linux-amd64-slim \
    /out/usr/local/bin/gomplate
RUN chmod +x /out/usr/local/bin/gomplate
COPY /apache2 /out/etc/apache2
COPY /entrypoint.sh /out/
COPY /apache.sh /out/
COPY /runApp.r /out/

FROM base
ENV PORT 8080
ENV SHINY_PORT 3838
COPY --from=build-env /out /
RUN a2enmod proxy proxy_http proxy_wstunnel rewrite auth_openidc remoteip && \
    a2ensite shiny
RUN a2enmod auth_cas
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/runApp.r", "-e", "01_hello"]
