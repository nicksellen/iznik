#!/bin/bash

set -e

dir=$(dirname "$0")

. $dir/inc.sh

sql-file iznik install/schema.sql
