#!/bin/bash

# Builds a single Open Liberty Docker Image
#  dir and tag must be specified, other arguments allow for overrides in development builds.

readonly usage="Usage: build.sh --dir <Dockerfile directory> --dockerfile <file name> --tag <image tag name> [--localTag <second image tag name>]"

main() {
  parse_args $@

  if [ -z "$dir" ] || [ -z "$tag" ]
  then
    echo "Error: Must specify --dir and --tag args"
    echo "$usage"
    return 1
  fi

  local buildCommand="docker build -t ${tag}"

  if [[ -z "${local_tag}" ]]; then
    buildCommand="${buildCommand} -t ${local_tag}"
  fi

  buildCommand="${buildCommand} -f ${dir}/${dockerfiles} ${dir}"
  echo "*** ${buildCommand}"
  eval "${buildCommand}"

  if [ $? = 0 ]; then
    echo "****"
    echo "Build successful ${dir} (${tag} ${local_tag})"
    echo "****"
  else
    echo "Build failed ${dir} (${tag} ${local_tag}), exiting."
    exit 1
  fi
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir)
        shift
        dir="${1#*=}"
        ;;
      --dockerfile)
        shift
        dockerfile="${1}"
        ;;
      --tag)
        shift
        tag="${1}"
        ;;
      --localTag)
        shift
        local_tag="${1}"
        ;;
      *)
        echo "Error: Invalid argument - $1"
        echo "$usage"
        exit 1
    esac
    shift
  done
}

main $@
