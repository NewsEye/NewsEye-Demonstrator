#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

$DIR/stop_services.sh
$DIR/remove_services.sh
$DIR/create_services.sh