#!/bin/bash
#########################################################################################
#
#
#     Script to build manifest list for each tags architectures (amd64, ppc64le, s390)
#     Note: As tag systems and liberty version support changes this must be updated
#
#
#########################################################################################

set -Eeo pipefail

## Globals to adjust as requirements change
readonly ARCHS=(amd64 ppc64le s390x)
readonly REPO="openliberty/open-liberty"
readonly RELEASES=(19.0.0.9 19.0.0.12 latest)
readonly TARGET_LATEST_TAG="full-java8-openj9-ubi"

main() {
  if [[ ! "$travis" = "true" || ! "$travis_pull_request" = "false" || ! "$travis_branch" = "master" ]]; then
    echo "****** Not a master branch build, skipping manifest generation..."
    return
  fi

  echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

  for rel in "${RELEASES[@]}"; do
    build_release_manifest "${rel}"
  done

  ## create alias tags for convenience and backwards support
  echo "****** Tagging latest as ${TARGET_LATEST_TAG}"
  create_alias "${TARGET_LATEST_TAG}" "latest"
  echo "****** Tagging kernel-java8-openj9-ubi as kernel-ubi-min"
  create_alias "kernel-java8-openj9-ubi" "kernel-ubi-min"

}

build_release_manifest() {
  local release="$1"

  echo "*** Building manifest lists for ${release}"
  while -r buildDir dockerfile repository imageTag imageTag2 imageTag3; do
    ## Create a FAT manifest list for imageTag
    create_manifest "${repository}:${imageTag}"
  done < "${release}/images.txt"
}

create_alias() {
  local from="$1"; shift
  local to="$1"

  ./manifest-tool push from-args --platforms "linux/amd64,linux/s390x,linux/ppc64le" --template "${REPO}:${from}-ARCH" --target "${REPO}:${to}"
}

create_manifest() {
  local target="$1"

  echo "****** Pulling in progress images"
  for a in "${ARCHS[@]}"; do
    docker pull "${target}-${a}-inprogress"
  done

  echo "****** Pushing arch images"
  for a in "${ARCHS[@]}"; do
    docker tag "${target}-${a}"
    echo "*** Pushing ${target}-${a}"
    docker push "${target}-${a}"
  done

  echo "****** Running manifest tool for ${target}"
  ./manifest-tool push from-args --platforms "linux/amd64,linux/s390x,linux/ppc64le" --template "${target}-ARCH" --target "${target}"
}


main $@
