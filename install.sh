#!/bin/bash

set -e

: ${SSH_TUNNEL_REMOTE_PORT:?}
: ${SSH_TUNNEL_CONNECTION:?}

echo "## Installing autossh"

apt-get install -y autossh

echo "## Replacing environment variables in service file"

BASEDIR=$(dirname "$BASH_SOURCE")
SERVICE_CONTENT=$(envsubst < $BASEDIR/autossh-tunnel.service.template)
echo "$SERVICE_CONTENT"
echo "$SERVICE_CONTENT" > /etc/systemd/system/autossh-tunnel.service

echo "## Reloading systemd, starting and enabling service on startup"

systemctl daemon-reload
systemctl start autossh-tunnel.service
systemctl enable autossh-tunnel.service