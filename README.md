This container image is built on the latest Alpine Linux for a lightweight footprint - reducing the final size to half of the official build - while prioritizing security by running as a non-root user by default.

## Additional features

### Vulkan

Vulkan image comes equipped with `htop` for real-time process monitoring and `radeontop` for tracking AMD GPU utilization and performance.

## Examples

### Docker Compose

If you decided to use docker's volume instead of path, remember to **set ownership** after starting the container so llama-swap's cache can be written on to said volume.

```yaml
services:
  llama-swap:
    container_name: llama-swap
    devices:
      # You can pass a specific device
      - /dev/dri
    environment:
      TZ: Etc/UTC
    group_add:
      # This value differs from machine to machine,
      # Run this command to get group ID: getent group render
      - 107         # render group
    image: knighthat/llama-swap:vulkan-non-root
    restart: unless-stopped
    user: '1000:1000'
    volumes:
      # Read-only config file
      - ./llama-swap.config.yaml:/app/config.yaml:ro
      # If you want to be able to download models from within
      # the container, remove read-only mode (:ro)
      - ./models:/models:ro
      - llama-cache:/app/.cache
      
volumes:
  # Don't forget to set ownership this volume once 
  # the container has started.
  llama-swap:
```

### Docker CLI

```sh
docker run -d \
  --name llama-swap \
  --restart unless-stopped \
  --user 1000:1000 \
  --device /dev/dri \
  --group-add 107 \
  -e TZ=Etc/UTC \
  -v ./llama-swap.config.yaml:/app/config.yaml:ro \
  -v ./models:/models:ro \
  -v llama-cache:/app/.cache \
  knighthat/llama-swap:vulkan-non-root
```
