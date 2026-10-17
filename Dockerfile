# ==========================================
# Stage 1: Build llama.cpp with Vulkan
# ==========================================
FROM alpine:latest AS llamabuilder

RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    vulkan-loader-dev \
    vulkan-headers \
    spirv-headers \
    spirv-tools-dev \
    shaderc-dev \
    linux-headers

WORKDIR /app/llama.cpp
COPY llama.cpp .

# Attempt to build then run 'llama-server --version' to check if segfault/core dump happens
# If it does, rebuild until run out of retries (3)
# If it doesn't, continue
RUN set -eu; \
    for attempt in 1 2 3; do \
      rm -rf build; \
      jobs=$([ "$attempt" -eq 1 ] && nproc || echo 1); \
      if cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
         && cmake --build build --config Release -j"$jobs" --target llama-server \
         && ./build/bin/llama-server --version; then \
        echo "build OK on attempt $attempt"; exit 0; \
      fi; \
      echo "attempt $attempt failed, rebuilding"; \
    done; \
    echo "llama.cpp build failed after 3 attempts"; exit 1

# ==========================================
# Stage 2: Build llama-swap
# ==========================================
FROM golang:alpine AS swapbuilder

RUN apk add --no-cache nodejs npm make

# Allow Go to automatically download the newer toolchain version specified in go.mod
ENV GOTOOLCHAIN=auto

WORKDIR /app/llama-swap
COPY llama-swap .

# Build only the Linux targets (avoids failing on macOS/Windows cross-compiles)
RUN make ui && make linux

# ==========================================
# Stage 3: Lightweight Unified Runtime
# ==========================================
FROM alpine:latest

WORKDIR /app
RUN mkdir -p /app

RUN apk add --no-cache \
    vulkan-loader \
    libstdc++ \
    libgomp \
    ca-certificates \
    mesa-vulkan-ati \
    radeontop \
    htop

# Copy compiled llama.cpp binaries
COPY --from=llamabuilder /app/llama.cpp/build/bin/llama-server /usr/bin/llama-server
# Copy the appropriate architecture binary for llama-swap (adjust amd64/arm64 if needed)
COPY --from=swapbuilder /app/llama-swap/build/llama-swap-linux-amd64 /usr/bin/llama-swap
# Copy default config file
COPY config.yaml /app/config.yaml

RUN addgroup -S app && adduser -S app -G app \
    && chown -R app:0 /app \
    && chmod -R g=u /app

USER app:0

EXPOSE 8080

HEALTHCHECK CMD wget -q -O /dev/null http://localhost:8080/health || exit 1
ENTRYPOINT ["llama-swap"]
CMD ["--config", "/app/config.yaml", "--watch-config"]
