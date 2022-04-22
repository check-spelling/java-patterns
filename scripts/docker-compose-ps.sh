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

# Usage example: /bin/sh ./scripts/docker-compose-ps.sh

set -o errexit
set -o nounset
set -o pipefail

## setup base directory
BASE_DIR=$(dirname "$0")/..
# DOCKER_COMPOSE_CMD stores docker compose command
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-$(command -v docker-compose || command -v docker compose)}

main() {
  echo ">>> Processing status of docker containers..."

  $DOCKER_COMPOSE_CMD --file "${BASE_DIR}/docker-compose.yml" ps
}

main "$@"
