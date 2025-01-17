#!/usr/bin/env bash

# Copyright 2021 The Cockroach Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then # Running inside bazel
  echo "Updating generated CRDs..." >&2
elif ! command -v bazel &>/dev/null; then
  echo "Install bazel at https://bazel.build" >&2
  exit 1
else
  (
    set -o xtrace
    bazel run //hack:update-crds
  )
  exit 0
fi

go=$(realpath "$1")
controllergen="$(realpath "$2")"
export PATH=$(dirname "$go"):$PATH

# This script should be run via `bazel run //hack:update-crds`
REPO_ROOT=${BUILD_WORKSPACE_DIRECTORY}
cd "${REPO_ROOT}"

"$controllergen" \
  crd:trivialVersions=true \
  rbac:roleName=cockroach-operator-role webhook \
  paths="./..." output:crd:artifacts:config=config/crd/bases

FILE_NAMES=(config/webhook/manifests.yaml config/rbac/role.yaml config/crd/bases/crdb.cockroachlabs.com_crdbclusters.yaml)

for YAML in "${FILE_NAMES[@]}"
do
   :
   cat "${REPO_ROOT}/hack/boilerplate/boilerplate.yaml.txt" "${REPO_ROOT}/${YAML}" > "${REPO_ROOT}/${YAML}.mod"
   mv "${REPO_ROOT}/${YAML}.mod" "${REPO_ROOT}/${YAML}"
done

fix_webhook_manifest() {
  for file in config/webhook/manifests.yaml; do
    local manifest="${REPO_ROOT}/${file}"
    # strip out null creationTimestamp
    sed '/creationTimestamp: null/d' "${manifest}" > "${manifest}.mod"
    mv "${manifest}.mod" "${manifest}"
  done
}

fix_webhook_manifest
