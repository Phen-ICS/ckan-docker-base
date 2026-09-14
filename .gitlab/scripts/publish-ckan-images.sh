#!/bin/sh
set -eu

. "$(dirname "$0")/common.sh"

build_and_push() {
  env_name="$1"
  tags="$2"
  set -- $tags
  primary_tag="$1"

  build_ckan_image "$env_name" "$primary_tag"

  for tag in $tags; do
    if [ "$tag" != "$primary_tag" ]; then
      docker tag "$primary_tag" "$tag"
    fi

    docker push "$tag"
  done
}

load_ckan_metadata

RELEASE_TAG="${CI_COMMIT_TAG:-$(git describe --tags --abbrev=0 2>/dev/null || echo "$CI_COMMIT_SHORT_SHA")}"
BASE_IMAGE="fair3r/ckan-base"
DEV_IMAGE="fair3r/ckan-dev"

BASE_TAGS="$BASE_IMAGE:$CKAN_MAJOR_VERSION $BASE_IMAGE:$VERSION_VALUE $BASE_IMAGE:$CKAN_MAJOR_VERSION-py$PYTHON_VERSION_VALUE $BASE_IMAGE:$VERSION_VALUE-py$PYTHON_VERSION_VALUE $BASE_IMAGE:$CKAN_MAJOR_VERSION-py$PYTHON_VERSION_VALUE-$RELEASE_TAG"
DEV_TAGS="$DEV_IMAGE:$CKAN_MAJOR_VERSION $DEV_IMAGE:$VERSION_VALUE $DEV_IMAGE:$CKAN_MAJOR_VERSION-py$PYTHON_VERSION_VALUE $DEV_IMAGE:$VERSION_VALUE-py$PYTHON_VERSION_VALUE $DEV_IMAGE:$CKAN_MAJOR_VERSION-py$PYTHON_VERSION_VALUE-$RELEASE_TAG"

build_and_push base "$BASE_TAGS"
build_and_push dev "$DEV_TAGS"
