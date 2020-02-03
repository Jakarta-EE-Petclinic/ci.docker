#!/bin/bash

readonly usage="Usage: buildAll.sh"
readonly tests=(test-pet-clinic test-stock-quote test-stock-trader)
readonly RELEASES=(19.0.0.9 19.0.0.12 latest)

main() {
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

  for rel in "${RELEASES[@]}"; do
    build_release "../releases/${rel}"
  done
}

build_release() {
  local releaseDir="$1"

  # Builds up the build.sh call to build each individual docker image listed in images.txt
  # only the first imageTag is required and only this will be pushed, others are local tags
  while read -r buildDir dockerfile repository imageTag imageTag2 imageTag3
  do
    ## include localTag so that new release `full` images can build
    local tag="${repository}:${imageTag}-${ARCH}-inprogress"
    local localTag="${repository}:${imageTag}"
    buildCommand="./build.sh --dir ${releaseDir}/${buildDir}  --dockerfile ${dockerfile} --tag ${tag} --localTag ${localTag}"

    echo "****** Running build script - ${buildCommand}"
    eval "${buildCommand}"

    if [ $? != 0 ]; then
      echo "****** Failed at image ${imageTag} (${buildDir}) - exiting"
      exit 1
    fi
  done < "${releaseDir}/images.txt"

  ## on master push images to dockerhub for manifest script
  if [[ "$travis" = "true" && "$travis_pull_request" = "false" && "$travis_branch" = "master" ]]; then
    echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
    echo "*** Pushing ${repository}:${tag}-inprogress"
    docker push "${repository}:${tag}-inprogress"
    return $?
  fi

  if [[ "${releaseDir}" =~ latest ]]; then
    test_images
  fi
}

test_images() {
  #Test the image
  for test in "${tests[@]}"; do
    testBuild="./build.sh --dir ${test} --dockerfile Dockerfile --tag ${test}"
    echo "*** Running build script for test - ${testBuild}"
    eval "${testBuild}"
    verifyCommand="./verify.sh ${test}"
    echo "*** Running verify script - ${verifyCommand}"
    eval "${verifyCommand}"
  done
}

main $@
