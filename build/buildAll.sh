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

  ## build base image for ibmjava tags
  build_ibmjava

  ## loop through versions and build
  for rel in "${RELEASES[@]}"; do
    echo "*******************************"
    echo "BUILDING RELEASE: ${rel}"
    echo "*******************************"
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

## replace user 1001 entries in ibmjava files and then build manually
build_ibmjava() {
  echo "*** Building ibmjava:8-ubi"
  mkdir java
  wget https://raw.githubusercontent.com/ibmruntimes/ci.docker/master/ibmjava/8/jre/ubi/Dockerfile -O java/Dockerfile
  wget https://raw.githubusercontent.com/ibmruntimes/ci.docker/master/ibmjava/8/sfj/ubi-min/Dockerfile -O java/Dockerfile-ubi-min
  ## replace references to user 1001 as we need to build as root
  sed -i.bak '/useradd -u 1001*/d' ./java/Dockerfile && \
    sed -i.bak '/USER 1001/d' ./java/Dockerfile && \
    rm java/Dockerfile.bak
  sed -i.bak '/useradd -u 1001*/d' ./java/Dockerfile-ubi-min && \
    sed -i.bak '/USER 1001/d' ./java/Dockerfile-ubi-min && \
    rm java/Dockerfile-ubi-min.bak
  ## tag UBI 8 as ibmjava:8-ubi and UBI 7 for older versions as ibmjava:8-ibmsfj-ubi-min
  docker build -t ibmjava:8-ubi java
  docker build -t ibmjava:8-ibmjsf-ubi-min -f ./java/Dockerfile-ubi-min java
}
main $@
