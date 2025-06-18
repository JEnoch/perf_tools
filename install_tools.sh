#!/bin/bash

if ! command -v perf 2>&1 >/dev/null; then
   echo "Install perf"
   sudo apt update
   sudo apt install -y linux-tools-generic
fi

if ! command -v atop 2>&1 >/dev/null; then
   echo "Install atop"
   sudo apt update
   sudo apt install -y atop
fi
