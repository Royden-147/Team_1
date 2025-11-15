#!/bin/bash
# start sshd in background, then exec original entrypoint
/usr/sbin/sshd || true
# exec the original postgres entrypoint
exec docker-entrypoint.sh "$@"
