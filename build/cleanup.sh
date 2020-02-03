#!/bin/bash
#########################################################################################
#
#
#     Delete pushed inprogress images after buildManifest or after failures
#
#
#########################################################################################

set -Eeo pipefail

readonly REPO="openliberty/open-liberty"
readonly RELEASES=(19.0.0.9 19.0.0.12 latest)

main() {
  if [[ "$TRAVIS" = "true" && "$TRAVIS_PULL_REQUEST" = "false" && "$TRAVIS_BRANCH" = "master" ]]; then
    for a in "${ARCHS[@]}"; do
      for rel in "${RELEASES[@]}"; do
        cleanup_release "${rel}" "${a}"
      done
    done
  else
    echo "****** Not a master build, nothing to cleanup"
    exit 0
  fi
}

cleanup_release() {
  local release="$1"; shift
  local arch="$1"

  ## loop through images, deleting the inprogress version for this arch
  while read -r buildDir dockerfile repository imageTag imageTag2 imageTag3; do
    echo "****** Getting auth token"
    local token=$(get_token)

    ## Delete tag from Dockerhub
    delete_tag "${REPO}" "${imageTag}-${arch}-inprogress" "${token}"
  done < "${release}/images.txt"
}

## @param repo a string representing the repository to delete the image from (i.e. ibmcom/websphere-liberty)
## @param tag the image tag to remove from the repo (i.e. kernel-java8-openj9-ubi-amd64-inprogress)
delete_tag () {
  local repo="$1"; shift
  local tag="$1"; shift
  local token="$1"

  if [[ -z "${repo}" || -z "${tag}" ]]; then
    echo "****** Warning: both repository name and image tag are required for deletion of tag"
    echo "****** Skipping deletion of in progress tag: ${tag} for repo: ${repo}"
  fi

  echo "****** Deleting ${repo}:${tag}"
  ## does nothing if no tag is found with that name
  curl -X DELETE -H "Authorization: Bearer ${token}" https://hub.docker.com/v2/repositories/${repo}/tags/${tag}/
}

## @returns value of auth token to dockerhub api
get_token() {
  local json=$(curl -s -X POST \
    -H "Content-Type: application/json"\
    -H "Accept: application/json" \
    -d '{"username":"'${USER}'","password":"'${PASS}'"}' https://hub.docker.com/v2/users/login/)

  ## see https://gist.github.com/cjus/1047794 for detail
  ## grab the token key/value pair
  local temp=$(echo $json \
    | sed 's/\\\\\//\//g' \
    | sed 's/[{}]//g'     \
    | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' \
    | sed 's/\"\:\"/\|/g' \
    | sed 's/[\,]/ /g'    \
    | sed 's/\"//g'       \
    | grep -w "token")
  local field="${temp##*|}"

  ## return the field value
  echo "${field#*: }"
}

main $@
