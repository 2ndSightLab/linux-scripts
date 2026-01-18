#!/bin/bash

# Standard AWS MFA uses TOTP (Time-based OTP), which requires knowing the current time. Since the YubiKey does not have an internal clock or battery, it cannot "type" a TOTP code on its own; it needs a computer app (like Yubico Authenticator) to provide the time. 
# OATH-HOTP is "event-based" rather than "time-based". It generates a new code every time you touch the button by incrementing a counter stored on the key. Because it doesn't need the time, the YubiKey can act as a standalone USB keyboard and "type" the code directly into your terminal. 
# How to set it up for 2026
# You only need to do this configuration once using the YubiKey Manager or Personalization Tool on your local machine:
#
# Programming the Slot:
# Open YubiKey Manager and go to Applications > OTP.
# Choose a slot (Slot 2 is recommended to avoid overwriting your default Yubico OTP).
# Select OATH-HOTP.
# Set the Digit length to 6 (required by AWS).
# Generate or enter a secret key (Base32 or Hex). Copy this key.
#
# Registering with AWS:
# In the AWS IAM Console, go to your user and click Assign MFA device.
# Select Authenticator app (Virtual MFA).
# Instead of scanning the QR code, click "Show secret key".
# Note: For this to work, you must ensure the secret key you programmed into your YubiKey matches the one provided by AWS. 
#
#When using a YubiKey for HOTP (HMAC-based One-Time Password), a new code is generated immediately upon a physical event, such as a touch. It does not have a time-based delay or expiration. 
#
# Key Characteristics of YubiKey HOTP:
#
# Immediate Generation: A new code is produced the instant you touch the YubiKey's gold contact (or scan it via NFC).
# Event-Driven: Unlike TOTP, which rotates codes every 30 seconds, HOTP only changes when you physically "trigger" it.
# No Time Expiration: The generated code remains valid until it is used for a successful login or until you generate a newer code that the server validates.
# Slot-Based: You can program HOTP into one of the YubiKey's two "OTP slots":
# Short Press (1-2.5s): Typically used for Slot 1.
# Long Press (3-5s): Typically used for Slot 2. 
# Usage Warning:
# Because it is event-based, pressing the button multiple times without logging in can cause the YubiKey's internal counter to get ahead of the server's counter. While most servers have a "look-ahead window" to account for this, excessive accidental presses may eventually require a resynchronization process. 
#
# Google AI contradictions:
#
# AWS Compatibility (Inaccurate): AWS IAM and AWS Identity Center strictly require the TOTP (Time-based) algorithm for virtual authenticator devices. If you program a YubiKey with a secret key using OATH-HOTP, the codes generated will quickly fall out of sync with AWS's expected time-based codes, and authentication will fail.
#
# AWS strictly does not support OATH-HOTP for MFA. Your script's logic is sound, but the authentication will fail because AWS requires TOTP (time-based) for the numeric codes your script expects.
# 
# One-time setup: You must use the YubiKey Manager on a different computer to program your AWS secret into the YubiKey.
# The Problem: Because the YubiKey has no internal clock, it cannot generate TOTP codes "by itself" to type into a terminal. It requires a host app (like Yubico Authenticator) to provide the time. 
#
# How to use it with the script
# Once configured, you don't need any software running. When the script reaches the read command:
# Ensure your cursor is in the terminal.
# Touch and hold your YubiKey (Slot 2 usually requires a long press of ~2 seconds).
# The YubiKey will "type" the 6-digit code and hit Enter for you

# Security:
# This script uses a subshell to wipe variables from memory after the script completes
# This is what Google's Gemini says about subshells (but do your own research)
#
# 1. Process Destruction
# A subshell (such as one created with ( ) or a pipe |) is typically a child process. When that child process completes, the operating system (OS) terminates it and reclaims all memory associated with it, including its stack and heap where variables were stored. 
# 2. Variable Isolation
# No Return to Parent: Any variables created or modified inside a subshell are copies. When the subshell ends, these changes are not reflected in the parent shell; they effectively cease to exist.
# Memory Clearing: The OS frees the memory pages used by the process, making them available to other programs. While the OS may not explicitly "zero out" every byte for performance reasons, the data is no longer accessible to your script or the shell. 
# 3. Exceptions and Persisting Data
#
#If you need data to survive the end of a subshell, you must explicitly move it out of the subshell's memory before it finishes: 
# Command Substitution: Use VAR=$(command) to capture the output of a subshell and store it in a parent shell variable.
# External Storage: Write data to a temporary file or a shared memory segment.
# Avoiding Subshells: If you want variables to persist in the current shell without being "wiped," avoid parentheses and use curly braces { ...; } or the source command to run code in the current execution environment.
# In other words, don't do those things if you want to make sure the memoary is cleared after authentication with Yubikey and secrets

(
    echo "Touch YubiKey..."
    # Read the YubiKey push into the subshell's memory
    read -s TOKEN_CODE < /dev/tty

    # Pull credentials from Secrets Manager using the EC2 instance role
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "my-aws-keys" --query SecretString --output text)

    # Use a subshell to strictly isolate and then wipe the MFA session
    (
        # Extract keys from the JSON
        LT_ACCESS_KEY=$(echo "$SECRET_JSON" | jq -r .access_key)
        LT_SECRET_KEY=$(echo "$SECRET_JSON" | jq -r .secret_key)
        MFA_SERIAL=$(echo "$SECRET_JSON" | jq -r .mfa_serial)

        # Get temporary session credentials
        STS_JSON=$(AWS_ACCESS_KEY_ID=$LT_ACCESS_KEY AWS_SECRET_ACCESS_KEY=$LT_SECRET_KEY \
                   aws sts get-session-token \
                   --serial-number "$MFA_SERIAL" \
                   --token-code "$TOKEN_CODE" \
                   --output json)

        # Export session tokens to the subshell environment
        export AWS_ACCESS_KEY_ID=$(echo "$STS_JSON" | jq -r '.Credentials.AccessKeyId')
        export AWS_SECRET_ACCESS_KEY=$(echo "$STS_JSON" | jq -r '.Credentials.SecretAccessKey')
        export AWS_SESSION_TOKEN=$(echo "$STS_JSON" | jq -r '.Credentials.SessionToken')

        # Execute the AWS action
        aws s3 ls
    )
)
# Memory is now clear; $TOKEN_CODE, $SECRET_JSON, and all AWS keys are gone.
