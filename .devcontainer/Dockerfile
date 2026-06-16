FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode
ARG CMAKE_VERSION=4.1.0
ARG SWIFT_URL=https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz

ENV SWIFT_HOME=/opt/swift
ENV PATH="${SWIFT_HOME}/usr/bin:/opt/cmake-${CMAKE_VERSION}-linux-x86_64/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        file \
        gettext \
        git \
        libfcitx5config-dev \
        libfcitx5core-dev \
        libfcitx5utils-dev \
        libgl1-mesa-dev \
        libglx-dev \
        libncurses6 \
        libprotoc-dev \
        libqt6gui6 \
        libqt6widgets6 \
        libvulkan-dev \
        libxkbcommon-dev \
        ninja-build \
        pkg-config \
        protobuf-compiler \
        qt6-base-dev \
        qt6-l10n-tools \
        qt6-tools-dev \
        qt6-tools-dev-tools \
        wget \
        glslc \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" \
    && tar xf "cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" -C /opt \
    && rm "cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"

RUN wget -q "${SWIFT_URL}" -O /tmp/swift.tar.gz \
    && mkdir -p "${SWIFT_HOME}" \
    && tar xf /tmp/swift.tar.gz --strip-components=1 -C "${SWIFT_HOME}" \
    && rm /tmp/swift.tar.gz

RUN usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m ubuntu \
    && groupmod -n "${USERNAME}" ubuntu

WORKDIR /workspaces/hazkey
USER ${USERNAME}
