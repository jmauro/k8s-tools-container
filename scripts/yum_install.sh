#!/bin/bash -e

ARGS="$*"

echo "Installing $ARGS"

yum update -y \
  && yum install -y ${ARGS} \
  && yum -y clean all \
  && rm -rf /var/cache
