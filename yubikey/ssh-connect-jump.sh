#!/bin/bash.sh

# Use this script to connect through a bastion host or jump server

# Risks
# While this method is significantly more secure than standard file-backed SSH keys, there are four key security risks to consider in 2026:
# 1. Agent Forwarding Risk
# The connect_yubikey.sh script suggests using ssh -A (Agent Forwarding) for remote use. 
# The Problem: If you forward your agent to a compromised remote server, a user with root access on that server can temporarily hijack your local SSH agent. They cannot steal your private key, but they can use your YubiKey to log into other servers you have access to as long as you are connected.
# 2026 Mitigation: Only use agent forwarding to highly trusted hosts. For hopping between servers, use ProxyJump (ssh -J) instead, which tunnels the connection without exposing your agent to the middle server. 
# 2. PIN Security
# Because you are not using a local private key file, the YubiKey becomes a single point of entry. 
# The Problem: If someone steals your YubiKey and knows (or guesses) your PIN, they have full access to your servers.
# 2026 Mitigation: Ensure you set a strong, non-sequential PIN. In 2026, YubiKeys are highly resistant to PIN brute-forcing, usually locking or wiping after 8 failed attempts. 
# 3. Cloning Vulnerabilities (Physical Access)
# In late 2024 and early 2025, researchers identified specific side-channel attacks (like "Eucleak") that could potentially clone some YubiKey models. 
# The Problem: An attacker with physical possession of your YubiKey and expensive specialized equipment could potentially extract the private key.
# 2026 Context: This is an extremely sophisticated attack requiring 24+ hours of physical access. For most users, this is not a practical risk, but it means physical security of the device remains paramount. 
# 4. Lockout Risk (Availability)
# Storing the private key only on the YubiKey means there is no backup. 
# The Problem: If you lose the YubiKey or it is physically damaged, you are permanently locked out of your remote hosts.
# Best Practice: Always set up two YubiKeys. Run the setup script for both and add both public keys to your remote authorized_keys file. Keep the second YubiKey in a secure, off-site location. 
# Summary of Best Practices 
# Avoid -A: Use ssh -J (ProxyJump) whenever possible.
# Use verify-required: Always include this in your setup to force a PIN prompt, preventing unauthorized use if the key is physically stolen.
# Physical Security: Do not leave the YubiKey unattended in your laptop

#!/bin/bash

# Configuration
JUMP_SERVER="jump_user@jump_host"
FINAL_DEST="target_user@target_host"

echo "1. Looking for YubiKey..."

# Start a temporary SSH agent for this session
eval $(ssh-agent -s)

# 2. Discover the key handle from the YubiKey directly into memory
# No files are written to your disk.
ssh-add -K

echo "2. Connecting via ProxyJump (Secure Tunneling)..."

# -J: Tunnels the connection through the jump server.
# Unlike agent forwarding, the jump server never sees your 'agent'.
# Your YubiKey will flash; touch it to authorize the final connection.
ssh -J "$JUMP_SERVER" "$FINAL_DEST"

# 3. Cleanup: Kill the agent and wipe memory on exit
ssh-agent -k
