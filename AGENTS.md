# Repository Guidelines

## Project Structure & Module Organization

This repository manages independent one-click installers for server infrastructure software. Do not add a root installer that installs multiple products.

- `k8s/`: Kubernetes installer, manifests, scripts, tools, and release metadata.
- `docker/`: Docker installer, scripts, tools, and release metadata.
- `standards/`: project conventions for scripts, logging, and releases.
- `templates/`: reusable shell templates for future installers.
- `releases/`: generated release artifacts; tarballs are ignored by Git.

Each product must keep its own `install.sh`, `config.env`, `scripts/`, `tools/`, and `release/` files.

## Build, Test, and Development Commands

Validate all shell scripts:

```bash
for f in $(find . -type f -name '*.sh' | sort); do sh -n "$f" || exit 1; done
sh -n k8s/config.env docker/config.env
```

Kubernetes manifest workflow:

```bash
./k8s/tools/audit-images.sh k8s/manifests/
IMAGE_MIRROR_PREFIX=swr.cn-north-4.myhuaweicloud.com/ddn-k8s ./k8s/tools/rewrite-images.sh k8s/manifests/
CN=1 ./k8s/tools/check-domains.sh k8s
./k8s/tools/build-release.sh
```

Build Docker release artifacts:

```bash
./docker/tools/build-release.sh
```

## Coding Style & Naming Conventions

Installer scripts should be POSIX `sh` compatible. Use 2-space indentation in shell functions and keep workflows split into numbered step scripts, for example `01-detect.sh` and `04-install-docker.sh`. Environment variables should be uppercase, configurable in `config.env`, and documented in the relevant README.

## Testing Guidelines

There is no formal test framework yet. At minimum, run shell syntax checks and any module-specific audit tools before committing. Do not test installers by running destructive commands on a developer machine unless the machine is intended for provisioning tests.

## Commit & Pull Request Guidelines

Use short imperative commit messages, matching the current history style, such as `Add Docker installer` or `Document Kubernetes release publishing`.

Pull requests should include:

- Summary of changed installer behavior.
- Commands run for validation.
- Notes for `CN=1` behavior, mirrors, or release artifacts if affected.
- Any manual provisioning test results, if performed.

## Security & Configuration Tips

Generated release tarballs and checksums under `releases/` are ignored by Git. Do not commit secrets, tokens, local `.env` files, or machine-specific installer state. `CN=1` runtime installs must not depend on GitHub, Docker Hub, `registry.k8s.io`, or other blocked upstream endpoints.
