# syntax=docker/dockerfile:1
FROM almalinux/10-minimal

# Build dependencies for PostgreSQL + TimescaleDB + pgvector (AlmaLinux 10 minimal).
RUN microdnf -y update \
  && microdnf -y --setopt=install_weak_deps=0 install \
    bison \
    bzip2 \
    ca-certificates \
    clang \
    cmake \
    flex \
    gcc \
    gcc-c++ \
    gettext \
    git \
    gzip \
    krb5-devel \
    libcurl-devel \
    libicu-devel \
    libselinux-devel \
    libsepol-devel \
    liburing-devel \
    libuuid-devel \
    libxml2-devel \
    libxslt-devel \
    llvm \
    llvm-devel \
    lld \
    lz4-devel \
    make \
    numactl-devel \
    openldap-devel \
    openssl-devel \
    pam-devel \
    perl \
    pkgconf-pkg-config \
    python3 \
    readline-devel \
    systemd-devel \
    tar \
    xz \
    zlib-devel \
    libzstd-devel \
  && microdnf clean all

# This is a throwaway builder image. It runs as root so build.sh can install into
# the real ${PREFIX} (/opt/pgsql/...) before packaging a relocatable tarball.
RUN mkdir -p /work /out
WORKDIR /work

COPY builder/build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh
ENTRYPOINT ["/usr/local/bin/build.sh"]
