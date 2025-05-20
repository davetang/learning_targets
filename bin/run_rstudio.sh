#!/usr/bin/env bash

set -euo pipefail

VER=4.5.0
IMAGE=davetang/rstudio:${VER}
NAME=rstudio_targets
PORT=7890
WORKING_DIR=$(realpath $(dirname $0)/..)
PACKAGE_DIR=${WORKING_DIR}/r_packages_${VER}

if [[ ! -d ${PACKAGE_DIR} ]]; then
   mkdir ${PACKAGE_DIR}
fi

docker run -d \
   --rm \
   -p ${PORT}:8787 \
   --name ${NAME} \
   -v ${PACKAGE_DIR}:/packages \
   -v ${WORKING_DIR}:/home/rstudio/work \
   -e PASSWORD=password \
   -e USERID=$(id -u) \
   -e GROUPID=$(id -g) \
   ${IMAGE}

>&2 echo ${NAME} listening on port ${PORT}
exit 0
