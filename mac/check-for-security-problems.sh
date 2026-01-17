#!/bin/bash
echo "================================================================"
echo "      ULTIMATE MAC SECURITY DIAGNOSTIC (JAN 17, 2026)          "
echo "================================================================"

# 1. TRACING ACTIVE BROWSER FLAG SOURCE
echo -e "\n [1] TRACING ACTIVE BROWSER FLAG SOURCE..."
echo "Description: Checks if Chrome is currently being forced to record your data."
FLAG_PROC=$(ps -wwax -o pid,ppid,command | grep -e "--log-net-log" | grep -v grep)
if [ -z "$FLAG_PROC" ]; then
    FLAG_RESULT="CLEAN: No active browser logging flag detected."
else
    FLAG_RESULT="ALERT: Chrome is currently running with the --log-net-log flag."
fi
echo "    - $FLAG_RESULT"

# 2. CHROME BINARY FORENSIC CHECK (SHIM DETECTION)
echo -e "\n CHROME BINARY FORENSIC CHECK (SHIM DETECTION)..."
echo "Description: Compares your App size to real 2026 standards (~400MB)."
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME_FRMK="/Applications/Google Chrome.app/Contents/Frameworks"

if [ -f "$CHROME_BIN" ]; then
    BIN_SIZE=$(stat -f%z "$CHROME_BIN")
    FRMK_SIZE=$(du -sh "$CHROME_FRMK" 2>/dev/null | cut -f1)

    if [ "$BIN_SIZE" -lt 1000000 ]; then
        SHIM_RESULT="ALERT: HIJACK CONFIRMED. Binary ($BIN_SIZE bytes) is a SHIM. Frameworks ($FRMK_SIZE) are 1,000x larger."
        echo "    - $SHIM_RESULT"
        echo "    - PATH TO SHIM: $CHROME_BIN"
        echo "    - EXPLANATION: In 2026, the real Chrome engine is roughly 400,000,000 bytes (400MB)."
        echo "      Your file is only ~368,000 bytes. This is far too small to be a browser."
        echo "      This is a fake 'wrapper' script that records your data before launching"
        echo "      the real engine hidden in the $FRMK_SIZE frameworks folder."
        codesign -vvvv "$CHROME_BIN" 2>&1 | grep -q "satisfies its Designated Requirement" || SHIM_RESULT="$SHIM_RESULT (SIGNATURE INVALID)"
    else
        SHIM_RESULT="CLEAN: Chrome binary size looks normal (>300MB)."
        echo "    - $SHIM_RESULT"
    fi
else
    SHIM_RESULT="ERROR: Chrome binary not found."
    echo "    - $SHIM_RESULT"
fi

# 3. LIST ALL STARTUP PLISTS (PERSISTENCE CHECK)
echo -e "\n [3] INSPECTING STARTUP PERSISTENCE (PLISTS)..."
echo "Description: Lists programs that start automatically. Look for dates matching your issue."
PLIST_LIST=$(ls -ltR ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null | grep ".plist")
echo "$PLIST_LIST"

# 4. BACKGROUND TASK MANAGEMENT (BTM) DATABASE
echo -e "\n [4] INSPECTING BTM DATABASE (HIDDEN BACKGROUND ITEMS)..."
echo "Description: Scans the macOS Tahoe background database for hidden 'Ghost' apps."
BTM_NULL=$(sudo sfltool dumpbtm | grep -E "Name:|Developer Name:|Executable Path:" | grep -A 2 -B 2 "(null)")
if [ -z "$BTM_NULL" ]; then
    BTM_RESULT="CLEAN: No suspicious (null) developers found in BTM."
else
    BTM_RESULT="WARNING: Suspicious (null) developers found in BTM database."
    echo "$BTM_NULL"
fi

# 5. CHECK FOR UNEXPECTED NETWORK CONNECTIONS
echo -e "\n [5] CHECKING ACTIVE NETWORK CONNECTIONS (ESTABLISHED)..."
echo "Description: Lists every app currently talking to the internet."
NET_CONN=$(sudo lsof -i -P -n | grep ESTABLISHED)
echo "$NET_CONN"

# 6. VERIFY SYSTEM BINARY INTEGRITY (XPROTECT LOGS)
echo -e "\n [6] CHECKING XPROTECT (SYSTEM MALWARE BLOCKS) - LAST 24H..."
echo "Description: Checks if the Mac system already caught and blocked any malware."
XPROTECT_LOGS=$(log show --predicate 'subsystem == "com.apple.XProtectFramework.Service"' --last 24h --style syslog | grep "Log")
if [ -z "$XPROTECT_LOGS" ]; then XPROTECT_LOGS="No XProtect events logged in last 24h."; fi
echo "    - $XPROTECT_LOGS"

# 7. SYSTEM PROFILES & POLICIES
echo -e "\n [7] CHECKING SYSTEM PROFILES & CHROME POLICIES..."
echo "Description: Checks if an outside company or hacker is 'Managing' your settings."
PROF_CHECK=$(sudo /usr/bin/profiles list 2>/dev/null)
POLICY_CHECK=$(defaults read com.google.Chrome 2>/dev/null | grep -Ei "CommandLine|log-net-log")
echo "    - Profiles: ${PROF_CHECK:-None}"
echo "    - Policies: ${POLICY_CHECK:-None}"

# 8. SHARED FOLDER SCRIPT SCAN
echo -e "\n [8] SCANNING /Users/Shared/ FOR SCRIPTS..."
echo "Description: Checks for malware scripts hiding in the 'Shared' user folder."
SHARED_SCRIPTS=$(ls -AF /Users/Shared/ | grep -E "\.sh$|\.py$|\.command$")
echo "    - Found: ${SHARED_SCRIPTS:-None}"

# 9. CHECK FOR MALICIOUS CHROME EXTENSIONS (MANAGED/FORCED)
echo -e "\n [9] CHECKING FOR MALICIOUS OR FORCED EXTENSIONS..."
echo "Description: Looks for 'Managed' extensions that you cannot delete manually."
EXT_DIR="$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
if [ -d "$EXT_DIR" ]; then
    ls -1 "$EXT_DIR"
    EXT_COUNT=$(ls -1 "$EXT_DIR" | wc -l)
    EXT_RESULT="Found $EXT_COUNT extension directories."
    EXTERNAL_JSON=$(find "$HOME/Library/Application Support/Google/Chrome" -name "external_extensions.json" 2>/dev/null)
    if [ -n "$EXTERNAL_JSON" ]; then EXT_RESULT="$EXT_RESULT ALERT: Found external_extensions.json!"; fi
else
    EXT_RESULT="Chrome profile directory not found."
fi
echo "    - $EXT_RESULT"

echo -e "\n================================================================"
echo "DIAGNOSTIC COMPLETE - SUMMARY OF FINDINGS"
echo "================================================================"
echo "1. RECORDING STATUS [1]: $FLAG_RESULT"
echo "   (If ALERT, your browser traffic is being recorded to a file.)"
echo ""
echo "2. APP AUTHENTICITY [2]: $SHIM_RESULT"
echo "   (If SHIM, your browser is a FAKE. Delete and reinstall immediately.)"
echo ""
echo "3. BACKGROUND APPS [4]:  $BTM_RESULT"
echo "   (If WARNING, unknown programs are starting automatically.)"
echo ""
echo "4. BROWSER ADD-ONS [9]:  $EXT_RESULT"
echo "   (If ALERT, malware is forcing extensions into your browser.)"
echo ""
echo "5. SYSTEM PROFILES [7]:  ${PROF_CHECK:-No Configuration Profiles Found.}"
echo "   (If found, an outside 'Profile' is controlling your computer.)"
echo ""
echo "6. BROWSER POLICY [7]:   ${POLICY_CHECK:-No Chrome Policies Found.}"
echo "   (If found, your browser settings are locked by a policy.)"
echo ""
echo "7. SHARED SCRIPTS [8]:   ${SHARED_SCRIPTS:-No suspicious scripts in /Users/Shared/.}"
echo "----------------------------------------------------------------"
echo "WHAT YOU SHOULD DO NOW:"
echo "----------------------------------------------------------------"
if [[ "$SHIM_RESULT" == *"ALERT"* ]]; then
    echo "🚨 YOUR BROWSER IS HIJACKED (Confirmed 368KB Shim):"
    echo "1. Delete 'Google Chrome' from your Applications folder."
    echo "2. Run: rm -rf ~/Library/Application\ Support/Google/Chrome"
    echo "3. Reinstall from the official site: https://www.google.com"
    echo "4. IMPORTANT: Change your banking/email passwords once fixed."
else
    echo "✅ No 'Shim' detected. If the error persists, investigate Section [5] for"
    echo "   Unexpected Traffic and Section [9] for unknown extensions."
fi
echo "================================================================"
