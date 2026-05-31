#!/bin/bash
set -ex
SCRIPT_DIR="$(dirname "$0")"
cd $SCRIPT_DIR

CERT=$1
CERT_BASE_DIR=out
NGINX_SSL_DIR=/nginx-ssl/

cp $CERT_BASE_DIR/${CERT}_ecc/fullchain.cer $NGINX_SSL_DIR/$CERT.cer

echo ======= acme has reload CERT: $CERT =========