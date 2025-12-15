#!/bin/bash
set -ex
docker network create --driver bridge --subnet=172.21.0.0/16 env-dev
