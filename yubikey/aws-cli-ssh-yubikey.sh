#!/bin/bash

# Supposedly this works. But earlier Google AI Mode said it won't work without yubikey manager because it doesn't have a clock in it. ???
#
# AWS does not support HMAC-based One-Time Password (HOTP) for standard IAM multi-factor authentication (MFA); it requires Time-based One-Time Password (TOTP). 
# However, your script still works because of how YubiKeys can be configured to act as a Virtual MFA device:
# Virtual MFA Simulation: When you set up MFA in the AWS Console, you typically choose "Authenticator app". Instead of scanning the QR code with a phone, you copy the Secret Key (the seed).
# YubiKey Customization: You then program that secret key into your YubiKey's "OTP" slot using the YubiKey Personalization Tool or ykman one time during initial setup. You can configure this slot to use the OATH-HOTP algorithm with a length that matches what AWS expects (typically 6 digits), but AWS will treat it as a "Virtual MFA" code.
# The "Keyboard" Trick: Once programmed, the YubiKey acts as a USB keyboard. When your script runs read -r MFA_TOKEN and you touch the key, the YubiKey "types" the current 6-digit code and hits Enter. The script receives this just as if you had typed it from a phone app. 
#
# Summary of why it works:
# AWS's Perspective: It thinks it is verifying a 6-digit code from a standard "Virtual MFA" (TOTP-compatible) app.
# The Script's Perspective: It is just waiting for keyboard input from /dev/tty [Original Script].
# The YubiKey's Perspective: It is acting as a keyboard to type a code into that prompt. 

# Configuring AWS

# Phase 1: Get the Secret Key from AWS
# Sign in to the AWS IAM Console.
# Navigate to Users, select your user, and click the Security credentials tab.
# In the Multi-factor authentication (MFA) section, click Assign MFA device.
# Select Authenticator app (this is essential to get the TOTP seed key) and click Next.
# Click Show secret key (do not scan the QR code) and copy the Base32 string (e.g., JBSWY3DPEB...). Keep this page open. 
# Phase 2: Program the YubiKey Slot
# Use the following ykman command to program the key to act as a keyboard that types a 6-digit code. Note that Slot 2 is usually best for this so you don't overwrite your primary (Slot 1) YubiKey OTP. 

# Replace <YOUR_SECRET_KEY> with the string from AWS
# Replace <ACCOUNT_NAME> with a label like "AWS-MFA"
# ykman otp chalresp --touch --secret <YOUR_SECRET_KEY> 2

#Alternatively, if you want the YubiKey to type a 6-digit TOTP code automatically on a long-press:
#bash
#ykman otp static --keyboard-layout US --append-return 2

#Note: Some newer models require the ykman oath app for TOTP. If the above does not output a 6-digit code when you long-press the gold contact in a text editor, use:
#bash
#ykman oath accounts add --issuer AWS --touch <ACCOUNT_NAME>

#Phase 3: Finalize AWS Registration
#Go back to the AWS Console page from Phase 1.
#Generate Code 1: Long-press your YubiKey (or run ykman oath code AWS) to type the first 6-digit code into the "MFA code 1" box.
#Generate Code 2: Wait 30 seconds for the next time window, then long-press again to type the second 6-digit code into "MFA code 2".
#Click Assign MFA. 

# Note none of that has yet been verfied

# Configuration
SECRET_ID="my/aws/iam/credentials"
REGION="us-east-1"

# Wrap entire logic in a subshell () to isolate variables from the environment
(
    # 1. Retrieve secret directly into memory (JSON format)
    # Uses instance role to fetch secret; results never touch a file
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$REGION" --query SecretString --output text)

    # 2. Extract credentials using jq
    AK=$(echo "$SECRET_JSON" | jq -r '.access_key')
    SK=$(echo "$SECRET_JSON" | jq -r '.secret_key')
    MFA_ARN=$(echo "$SECRET_JSON" | jq -r '.mfa_arn')

    # 3. Prompt for YubiKey touch using /dev/tty
    # This ensures the prompt is visible even if the script output is redirected
    echo "Please touch your YubiKey now..." > /dev/tty
    
    # Read the YubiKey OTP from /dev/tty (YubiKey types the code + Enter)
    read -r MFA_TOKEN < /dev/tty

    # 4. Get temporary credentials with MFA
    # We prefix variables to the command to avoid persistent env vars
    TEMP_CREDS=$(AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" \
        aws sts get-session-token \
        --serial-number "$MFA_ARN" \
        --token-code "$MFA_TOKEN" \
        --region "$REGION" \
        --output json)

    # 5. Extract and use temporary credentials to run your final AWS command
    # This runs the target command (e.g., get-caller-identity) with the new MFA-authorized token
    AWS_ACCESS_KEY_ID=$(echo "$TEMP_CREDS" | jq -r '.Credentials.AccessKeyId') \
    AWS_SECRET_ACCESS_KEY=$(echo "$TEMP_CREDS" | jq -r '.Credentials.SecretAccessKey') \
    AWS_SESSION_TOKEN=$(echo "$TEMP_CREDS" | jq -r '.Credentials.SessionToken') \
    aws sts get-caller-identity --region "$REGION"

) # Subshell ends; AK, SK, and Tokens are cleared from memory
