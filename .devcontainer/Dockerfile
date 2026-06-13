# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.177.0/containers/cpp/.devcontainer/base.Dockerfile

# [Choice] Debian / Ubuntu version: debian-10, debian-9, ubuntu-20.04, ubuntu-18.04
ARG VARIANT="ubuntu-22.04"

FROM mcr.microsoft.com/vscode/devcontainers/cpp:0-$VARIANT

ENV TOOLCHAINURL="https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel"
ENV TOOLCHAINARCHIVE="arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi.tar.xz"
ENV TOOLCHAINDIR="arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi"
ENV PICO_SDK_VERSION="2.0.0"

RUN set -eux; \
    apt-get update; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get -y install --no-install-recommends \
        cmake \
        build-essential \
        wget \
        ca-certificates \
        gdb-multiarch \
        automake \
        autoconf \
        libtool \
        libftdi-dev \
        libusb-1.0-0-dev \
        pkg-config \
        clang-format \
        libhidapi-dev; \
    rm -rf /var/lib/apt/lists/*
WORKDIR /apps

RUN set -eux; \
    mkdir -p /apps/gcc-arm-none; \
    wget -O "/tmp/${TOOLCHAINARCHIVE}" "${TOOLCHAINURL}/${TOOLCHAINARCHIVE}"; \
    tar -xJf "/tmp/${TOOLCHAINARCHIVE}" -C /apps/gcc-arm-none --strip-components=1; \
    rm "/tmp/${TOOLCHAINARCHIVE}"
ENV PATH=$PATH:/apps/gcc-arm-none/bin

RUN set -eux; \
    git clone -b "$PICO_SDK_VERSION" https://github.com/raspberrypi/pico-sdk.git --depth=1; \
    git -C pico-sdk submodule update --init --depth=1
ENV PICO_SDK_PATH=/apps/pico-sdk
ENV OPENOCD_VERSION="v0.12.0"
ENV PICOTOOL_VERSION="2.0.0"
ENV BOOTTERM_VERSION="v0.5"

RUN set -eux; \
    git clone -b "$OPENOCD_VERSION" https://github.com/openocd-org/openocd.git --depth=1 --recurse-submodules; \
    cd openocd; \
    ./bootstrap; \
    ./configure --enable-internal-jimtcl --enable-ftdi --enable-sysfsgpio --enable-picoprobe --enable-cmsis-dap; \
    make -j"$(nproc)" install; \
    cd /apps; \
    rm -rf openocd

RUN set -eux; \
    git clone -b "$PICOTOOL_VERSION" https://github.com/raspberrypi/picotool.git --depth=1; \
    cmake -S picotool -B picotool/build; \
    cmake --build picotool/build --parallel "$(nproc)"; \
    cp picotool/build/picotool /usr/local/bin/picotool; \
    rm -rf picotool

RUN set -eux; \
    git clone -b "$BOOTTERM_VERSION" https://github.com/wtarreau/bootterm.git --depth=1; \
    make -C bootterm -j"$(nproc)" install; \
    rm -rf bootterm

RUN usermod -aG plugdev vscode
