#!/bin/bash

set -e

dir=$(dirname "$0")

. $dir/inc.sh

mkdir -p composer/vendor
composer install
