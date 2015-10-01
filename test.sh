#!/bin/bash

# load the in.ini INI file to current BASH - quoted to preserve line breaks
eval "$(cat config.ini  | ./scripts/ini2arr.py)"

# test it:
echo ${compute02[mgmt_addr]}
