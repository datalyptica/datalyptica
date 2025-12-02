# Datalyptica Repository & Docker Registry Setup Guide

This guide walks you through pushing the Datalyptica codebase and Docker images to your new GitHub organization.

## Prerequisites

- [x] Created GitHub organization: **datalyptica**
- [ ] GitHub Personal Access Token (PAT) with permissions:
  - `repo` (full control of private repositories)
  - `write:packages` (upload packages to GitHub Package Registry)
  - `delete:packages` (delete packages from GitHub Package Registry)
  - `read:org` (read org data)

## Step 1: Create GitHub Repository

1. Go to: https://github.com/organizations/datalyptica/repositories/new
2. Fill in:
   - **Repository name:** `datalyptica`
   - **Description:** `Enterprise-Grade Data Lakehouse Platform`
   - **Visibility:** Choose Public or Private
   - **DO NOT** check "Initialize this repository with a README"
3. Click **Create repository**

## Step 2: Push Code to GitHub

Once the repository is created, run:

```bash
cd /Users/karimhassan/development/projects/shudl

# Add the new remote (replace if already exists)
git remote remove datalyptica 2>/dev/null || true
git remote add datalyptica https://github.com/datalyptica/datalyptica.git

# Push code to the new organization
git push -u datalyptica main

# Optional: Push tags if you have any
git push datalyptica --tags
```

### Verify Code Push

Check your repository at: https://github.com/datalyptica/datalyptica

## Step 3: Authenticate Docker with GitHub Container Registry

You need to authenticate Docker with GitHub Container Registry (GHCR) to push images.

### Create a GitHub Personal Access Token (if you don't have one)

1. Go to: https://github.com/settings/tokens
2. Click **Generate new token** → **Generate new token (classic)**
3. Give it a name: `Datalyptica Docker Registry`
4. Select scopes:
   - [x] `write:packages`
   - [x] `read:packages`
   - [x] `delete:packages`
5. Click **Generate token**
6. **COPY THE TOKEN** (you won't see it again!)

### Login to GitHub Container Registry

```bash
# Set your GitHub username
export GITHUB_USERNAME="your-github-username"

# Set your GitHub token (the one you just created)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

You should see:

```
Login Succeeded
```

## Step 4: Build Docker Images

Build all 19 Docker images for the Datalyptica platform:

```bash
cd /Users/karimhassan/development/projects/shudl

# Set the version (optional, defaults to v1.0.0)
export DATALYPTICA_VERSION=v1.0.0

# Build all images (this will take 15-30 minutes)
./scripts/build/build-all-images.sh
```

The script will build images in this order:

1. **Core Services:** minio, postgresql, patroni, nessie, trino, spark
2. **Streaming:** zookeeper, kafka, schema-registry, flink, kafka-connect
3. **OLAP:** clickhouse
4. **ETL:** dbt
5. **Analytics & ML:** great-expectations, airflow, jupyterhub, jupyterlab-notebook, mlflow, superset

### Monitor Build Progress

Each image build will show output. If any fail, check:

- Docker is running: `docker info`
- Enough disk space: `df -h`
- Build logs in `/tmp/build-*.log`

## Step 5: Push Docker Images to Registry

After all images are built, push them to GHCR:

```bash
# Push all images (this will take 10-20 minutes depending on internet speed)
./scripts/build/push-all-images.sh
```

### Verify Images Were Pushed

1. Go to: https://github.com/orgs/datalyptica/packages
2. You should see all 19 packages listed
3. Each package should show both `:v1.0.0` and `:latest` tags

## Step 6: Update Local Repository Settings

Now that your code is in the new organization, you can update your local repo:

```bash
# Set the new origin as default
git remote set-url origin https://github.com/datalyptica/datalyptica.git

# Verify
git remote -v
```

You should see:

```
datalyptica  https://github.com/datalyptica/datalyptica.git (fetch)
datalyptica  https://github.com/datalyptica/datalyptica.git (push)
origin       https://github.com/datalyptica/datalyptica.git (fetch)
origin       https://github.com/datalyptica/datalyptica.git (push)
```

## Step 7: Test Pulling Images

Test that the images are accessible:

```bash
# Pull a test image
docker pull ghcr.io/datalyptica/datalyptica/minio:latest

# Verify
docker images | grep datalyptica
```

## Step 8: Update docker-compose.yml (if needed)

Your `docker-compose.yml` already uses the correct image paths:

```yaml
image: ghcr.io/datalyptica/datalyptica/<service>:${DATALYPTICA_VERSION:-v1.0.0}
```

To use the pushed images instead of building locally:

```bash
# Pull all images from registry
cd docker
docker compose pull

# Start services
docker compose up -d
```

## Complete Checklist

- [ ] Created GitHub organization: `datalyptica`
- [ ] Created repository: `datalyptica/datalyptica`
- [ ] Generated GitHub Personal Access Token
- [ ] Logged into GitHub Container Registry
- [ ] Pushed code: `git push datalyptica main`
- [ ] Built all Docker images: `./scripts/build/build-all-images.sh`
- [ ] Pushed all Docker images: `./scripts/build/push-all-images.sh`
- [ ] Verified packages at: https://github.com/orgs/datalyptica/packages
- [ ] Updated local git remote
- [ ] Tested pulling images

## Quick Reference Commands

```bash
# Build all images
./scripts/build/build-all-images.sh

# Push all images
./scripts/build/push-all-images.sh

# Build and push specific service
docker build -t ghcr.io/datalyptica/datalyptica/minio:v1.0.0 deploy/docker/minio/
docker push ghcr.io/datalyptica/datalyptica/minio:v1.0.0

# List all built images
docker images | grep datalyptica

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

## Troubleshooting

### "denied: permission_denied" when pushing

- Ensure your PAT has `write:packages` scope
- Re-login: `docker logout ghcr.io` then login again
- Verify token hasn't expired

### "unauthorized: unauthenticated" when pulling

- Images are private by default
- Go to each package settings and make it public
- Or ensure you're logged in with correct credentials

### Build failures

- Check Docker daemon: `docker info`
- Check disk space: `df -h`
- View build logs: `cat /tmp/build-<service>.log`
- Build individual service: `docker build -t test deploy/docker/<service>/`

### Image size too large

- Images use multi-stage builds to minimize size
- Remove old images: `docker system prune -a`
- Check layer caching is working

## Next Steps

After successful deployment:

1. **Set up CI/CD**: Create GitHub Actions workflows for automated builds
2. **Configure package visibility**: Make packages public or set team permissions
3. **Add README to packages**: Describe each service's Docker image
4. **Version tagging**: Tag releases with semantic versioning
5. **Documentation**: Update all docs to reference new organization

## Resources

- GitHub Container Registry: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- Docker Documentation: https://docs.docker.com/
- Datalyptica Branding: See `DATALYPTICA_BRANDING.md`

---

**© 2025 Datalyptica. All rights reserved.**
