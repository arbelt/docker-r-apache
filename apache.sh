#!/usr/bin/env bash

set -e

source /etc/apache2/envvars
exec /usr/sbin/apache2 -DFOREGROUND
