#!/bin/sh
set -eu

load_ckan_metadata() {
  CKAN_VERSION_DIR="ckan-${CKAN_MAJOR_VERSION}"
  VERSION_VALUE="$(tr -d '\r\n' < "${CKAN_VERSION_DIR}/VERSION.txt")"
  PYTHON_VERSION_VALUE="$(tr -d '\r\n' < "${CKAN_VERSION_DIR}/PYTHON_VERSION.txt")"
  CKAN_REF="$VERSION_VALUE"

  case "$VERSION_VALUE" in
    master|dev*) ;;
    *) CKAN_REF="ckan-$VERSION_VALUE" ;;
  esac

  export CKAN_VERSION_DIR VERSION_VALUE PYTHON_VERSION_VALUE CKAN_REF
}

build_ckan_image() {
  env_name="$1"
  image_tag="$2"

  docker build \
    --build-arg="CKAN_REF=$CKAN_REF" \
    --build-arg="ENV=$env_name" \
    --build-arg="PYTHON_VERSION=$PYTHON_VERSION_VALUE" \
    -t "$image_tag" \
    "$CKAN_VERSION_DIR"
}
