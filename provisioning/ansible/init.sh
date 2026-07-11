#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd $DIR

bash ./run.sh linux-init

bash ./run.sh docker

bash ./run.sh k3s