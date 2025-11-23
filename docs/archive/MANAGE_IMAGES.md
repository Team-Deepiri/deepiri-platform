# Managing Docker Images

## Check Images

### List All Images
```bash
# Make sure Docker is pointing to Minikube
eval $(minikube docker-env)

# List all images
docker images

# List only deepiri images
docker images | grep deepiri

# List only deepiri-dev images
docker images | grep "deepiri-dev"
```

### Check Specific Image
```bash
# Check if a specific image exists
docker images deepiri-dev-api-gateway

# Check all tags for an image
docker images deepiri-dev-api-gateway --format "{{.Repository}}:{{.Tag}}"
```

## Delete Images

### Delete Specific Image
```bash
# Delete by name:tag
docker rmi deepiri-dev-api-gateway:latest

# Delete by image ID
docker rmi <IMAGE_ID>

# Force delete (if container is using it)
docker rmi -f deepiri-dev-api-gateway:latest
```

### Delete All Deepiri Images
```bash
# Delete all deepiri-dev images
docker images | grep "deepiri-dev" | awk '{print $3}' | xargs docker rmi -f

# Or more safely, delete by name pattern
docker rmi $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "deepiri-dev") -f
```

### Delete All Unused Images
```bash
# Remove all unused images (not used by containers)
docker image prune -a

# Remove with confirmation prompt
docker image prune -a --interactive
```

### Delete Everything (Nuclear Option)
```bash
# Delete ALL images (be careful!)
docker rmi $(docker images -q) -f

# Or use prune
docker image prune -a --force
```

## Check Image Sizes

```bash
# Show image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Show only deepiri images with sizes
docker images | grep deepiri | awk '{print $1":"$2, $7}'
```

## Useful Commands

### Check What's Using an Image
```bash
# List containers using an image
docker ps -a --filter "ancestor=deepiri-dev-api-gateway:latest"
```

### Clean Up Everything
```bash
# Stop all containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all images
docker rmi $(docker images -q) -f

# Remove all volumes
docker volume prune -f

# Remove all networks (except defaults)
docker network prune -f
```

## Quick Reference

```bash
# Setup
eval $(minikube docker-env)

# Check images
docker images | grep deepiri-dev

# Delete one image
docker rmi deepiri-dev-api-gateway:latest

# Delete all deepiri-dev images
docker rmi $(docker images --format "{{.Repository}}:{{.Tag}}" | grep "deepiri-dev") -f

# Clean up unused
docker image prune -a
```

