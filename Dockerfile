# SpinorBEC dev container.
#
# CPU-only image — usable for fast tier tests, dashboard development,
# and YAML editing. For GPU work mount the host's CUDA driver and run
# directly on the host (devcontainers don't pass GPUs reliably).
#
# Build:
#   docker build -t spinorbec:dev .
# Run interactive:
#   docker run -it --rm -v "$PWD":/workspaces/BEC-simulation \
#       -w /workspaces/BEC-simulation spinorbec:dev julia --project=.

FROM julia:1.12-bookworm

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git ca-certificates curl ffmpeg less vim \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME
WORKDIR /workspaces/BEC-simulation

# Pre-warm Pkg cache by depending on Project.toml only (better caching)
COPY --chown=$USERNAME:$USERNAME Project.toml /tmp/Project.toml
RUN julia --project=/tmp -e 'using Pkg; Pkg.instantiate()' || true

CMD ["julia"]
