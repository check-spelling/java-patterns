#!/usr/bin/env bash
# Copyright (C) 2022 SensibleMetrics, Inc. (http://sensiblemetrics.io/)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Usage example: /bin/sh ./scripts/docker-rebuild.sh

set -o errexit
set -o nounset
set -o pipefail

# Docker image params
DEFAULT_IMAGE_REPOSITORY="styled-java-patterns"
DEFAULT_IMAGE_TAG="latest"

readonly IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-$DEFAULT_IMAGE_REPOSITORY}"
readonly IMAGE_TAG="${IMAGE_TAG:-$DEFAULT_IMAGE_TAG}"
readonly GIT_SHA=$(git rev-parse HEAD)

## setup base directory
BASE_DIR=$(dirname "$0")/..
# DOCKER_CMD stores docker command
DOCKER_CMD=${DOCKER_CMD:-$(command -v docker 2> /dev/null || command -v podman 2> /dev/null || type -p docker)}

main() {
  echo ">>> Rebuilding docker container..."

  # docker file tag
  local tag
  tag="$1"

  # docker file path
  local file
  file="${BASE_DIR}/distribution/docker-images/${tag}.Dockerfile"

  # Build docker image
  $DOCKER_CMD build \
    --rm \
    --file "$file" \
    --tag "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
    --tag "${IMAGE_REPOSITORY}:${GIT_SHA}" \
    --no-cache=true \
    "${BASE_DIR}"
}

main "$@"
