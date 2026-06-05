#!/bin/sh
set -eu

. "$(dirname "$0")/common.sh"

TEST_NETWORK="ckan-test"
BASE_IMAGE="ckan-base-${CKAN_MAJOR_VERSION}-local"
DEV_IMAGE="ckan-dev-${CKAN_MAJOR_VERSION}-local"

cleanup() {
  docker rm -f solr postgres redis >/dev/null 2>&1 || true
  docker network rm "$TEST_NETWORK" >/dev/null 2>&1 || true
}

start_services() {
  docker network create "$TEST_NETWORK"
  docker run -d --name solr --network "$TEST_NETWORK" "ckan/ckan-solr:${CKAN_MAJOR_VERSION}-solr9"
  docker run -d --name postgres --network "$TEST_NETWORK" \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=postgres \
    --health-cmd pg_isready \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 5 \
    "ckan/ckan-postgres-dev:${CKAN_MAJOR_VERSION}"
  docker run -d --name redis --network "$TEST_NETWORK" redis:7
}

wait_for_postgres() {
  for i in $(seq 1 30); do
    if [ "$(docker inspect -f '{{.State.Health.Status}}' postgres)" = "healthy" ]; then
      return 0
    fi

    if [ "$i" -eq 30 ]; then
      docker logs postgres
      return 1
    fi

    sleep 2
  done
}

wait_for_solr() {
  for i in $(seq 1 30); do
    if docker run --rm --network "$TEST_NETWORK" busybox:1.36 wget -q -O /dev/null http://solr:8983/solr/; then
      return 0
    fi

    if [ "$i" -eq 30 ]; then
      docker logs solr
      return 1
    fi

    sleep 2
  done
}

run_ckan_command() {
  image_tag="$1"
  shift

  docker run \
    --rm \
    --network "$TEST_NETWORK" \
    -e CKAN_SQLALCHEMY_URL=postgresql://ckan_default:pass@postgres/ckan_test \
    -e CKAN_DATASTORE_WRITE_URL=postgresql://datastore_write:pass@postgres/datastore_test \
    -e CKAN_DATASTORE_READ_URL=postgresql://datastore_read:pass@postgres/datastore_test \
    -e CKAN_SOLR_URL=http://solr:8983/solr/ckan \
    -e CKAN_REDIS_URL=redis://redis:6379/1 \
    -e CKAN_INI=/srv/app/src/ckan/test-core.ini \
    --entrypoint "" \
    "$image_tag" \
    "$@"
}

test_child_image_build() {
  printf 'FROM %s\n' "$BASE_IMAGE" > Dockerfile.child
  docker build -f Dockerfile.child .
}

trap cleanup EXIT

load_ckan_metadata
start_services
wait_for_postgres
wait_for_solr

build_ckan_image base "$BASE_IMAGE"
run_ckan_command "$BASE_IMAGE" ckan --help
test_child_image_build

build_ckan_image dev "$DEV_IMAGE"
run_ckan_command "$DEV_IMAGE" pytest --ckan-ini=/srv/app/src/ckan/test-core.ini -v /srv/app/src/ckan/ckan/tests/logic/action/test_create.py::TestDatasetCreate
