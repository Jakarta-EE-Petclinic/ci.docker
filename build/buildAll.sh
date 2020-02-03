#!/bin/bash

readonly usage="Usage: buildAll.sh --release <release>"
readonly tests=(test-pet-clinic test-stock-quote test-stock-trader)

main() {
  parse_args $@

  if [[ -z "${RELEASE}" ]]; then
    echo "****** No release provided for build, exiting..."
    exit 1
  fi

  ## Define current arc variable
  case "$(uname -p)" in
    "ppc64le")
      ARCH="ppc64le"
      ;;
    "s390x")
      ARCH="s390x"
      ;;
    *)
      ARCH="amd64"
  esac

  # Builds up the build.sh call to build each individual docker image listed in images.txt
  # only the first imageTag is required and only this will be pushed, others are local tags
  while read -r buildDir dockerfile repository imageTag imageTag2 imageTag3
  do
    ## include localTag so that new release `full` images can build
    local tag="${repository}:${imageTag}-${ARCH}-inprogress"
    local localTag="${repository}:${imageTag}"
    buildCommand="./build.sh --dir=${RELEASE}/${buildDir}  --dockerfile=${dockerfile} --tag=${tag} --localTag=${localTag}"

    echo "****** Running build script - ${buildCommand}"
    eval "${buildCommand}"

    if [ $? != 0 ]; then
      echo "****** Failed at image ${imageTag} (${buildDir}) - exiting"
      exit 1
    fi
  done < "${RELEASE}/images.txt"

  ## on master push images to dockerhub for manifest script
  if [[ "$travis" = "true" && "$travis_pull_request" = "false" && "$travis_branch" = "master" ]]; then
    echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
    echo "*** Pushing ${repository}:${tag}-inprogress"
    docker push "${repository}:${tag}-inprogress"
    return $?
  fi

  test_images
}

test_images() {
  if [[ "${RELEASE}" =~ latest ]]; then
    #Test the image
    for test in "${tests[@]}"; do
      testBuild="./build.sh --dir=${test} --dockerfile=Dockerfile --tag=${test}"
      echo "*** Running build script for test - ${testBuild}"
      eval "${testBuild}"
      verifyCommand="./verify.sh ${test}"
      echo "*** Running verify script - ${verifyCommand}"
      eval "${verifyCommand}"
    done
  fi
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --release)
      shift
      readonly RELEASE="${1}"
      ;;
    *)
      echo "*** Error: Invalid argument - $1"
      echo "$usage"
      exit 1
      ;;
    esac
    shift
  done
}

main $@
