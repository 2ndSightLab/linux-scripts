#!/bin/bash

# Connect directly to an SSH server with Yubikey

# Configure yubikey using this script first: configure-yubikey-for-ssh-mac.sh
# Then use this script to connect to the remote host with your Yubikey
# Connect to remote host using Yubikey after configuration is complete using this script.
# If you are connecting through an intermediary server this is not secure - use ssh-connect-jump.sh instead.
# By using ssh-add -K and ssh-agent -k, your "identity" exists only in your Mac's RAM for the duration of the connection. As soon as you log out, that memory is wiped.

# Configuration
REMOTE_USER="your_username"
REMOTE_HOST="your_server_ip"

echo "1. Looking for YubiKey..."

# Start a temporary SSH agent in the background for this session
eval $(ssh-agent -s)

# 2. Discover the key handle from the YubiKey directly into agent memory
# This pulls the 'identity' from the hardware without writing any files to disk.
ssh-add -K

echo "2. Connecting directly to $REMOTE_HOST..."
# -o IdentitiesOnly=yes: Ensures only the key currently in the agent (your YubiKey) is used.
# The YubiKey will flash; touch it to authorize the session.
ssh -o IdentitiesOnly=yes "${REMOTE_USER}@${REMOTE_HOST}"

# 3. Cleanup: Kill the agent and wipe memory on exit
ssh-agent -k
