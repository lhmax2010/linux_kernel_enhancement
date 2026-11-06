#!/bin/sh
set -eu
export TMPDIR=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/task24
export PYTHONDONTWRITEBYTECODE=1
exec systemd-run --user --scope -p CPUQuota=400% -p MemoryMax=8G nice -n 10 ionice -c3 "$@"
