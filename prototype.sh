#!/bin/sh
printf '\033c\033]0;%s\a' prototype
base_path="$(dirname "$(realpath "$0")")"
"$base_path/prototype.x86_64" "$@"
