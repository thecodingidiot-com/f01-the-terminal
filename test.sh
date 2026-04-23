#!/bin/bash

set -o pipefail

# Per-user scratch directory.
# The UID suffix prevents two users on the same machine from stomping on
# each other's state — a real concern on shared lab machines or CI runners.
# XDG_RUNTIME_DIR is preferred (per-user, tmpfs) when available (systemd
# systems); /tmp with the UID appended is the portable fallback.
SCRATCH="${XDG_RUNTIME_DIR:-/tmp}/f01-test-$(id -u)"
STATE_FILE="$SCRATCH/.state"
BG_PID_FILE="$SCRATCH/.bg-pid"

cleanup_bg() {
    [ -f "$BG_PID_FILE" ] && kill "$(cat "$BG_PID_FILE")" 2>/dev/null
}
trap cleanup_bg EXIT

# Color codes (disabled if not a tty)
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_RESET='\033[0m'

if [ ! -t 1 ]; then
    C_GREEN=''
    C_RED=''
    C_RESET=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

hr() {
    echo "────────────────────────────────────────────"
}

banner() {
    echo "════════════════════════════════════════════"
    echo "  f01 — The Terminal  /  test.sh"
    echo "════════════════════════════════════════════"
}

challenge_title() {
    local num="$1"
    case "$num" in
        1)  echo "Navigation and file creation" ;;
        2)  echo "Copy, move, delete" ;;
        3)  echo "Permissions — executable script" ;;
        4)  echo "grep to file" ;;
        5)  echo "find to file" ;;
        6)  echo "Pipeline to file" ;;
        7)  echo "Append redirect" ;;
        8)  echo "Kill a background process" ;;
        9)  echo "Environment variable in ~/.bashrc" ;;
        10) echo "Text substitution — vim or sed" ;;
        11) echo "NetHack installed" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Setup fixtures
# ─────────────────────────────────────────────────────────────────────────────

setup_fixtures() {
    mkdir -p "$SCRATCH/project/src" "$SCRATCH/project/docs" "$SCRATCH/logs" || {
        echo "Error: could not create scratch directory at $SCRATCH"
        echo "Check permissions and available disk space."
        exit 1
    }

    echo "touch me later" > "$SCRATCH/project/src/original.txt"

    echo -e "hello world\nfoo bar\nbaz qux" > "$SCRATCH/project/docs/readme.txt"
    touch "$SCRATCH/project/docs/notes.log"

    cat > "$SCRATCH/logs/app.log" <<'EOF'
[INFO] Application started
[ERROR] Connection failed
[INFO] Retrying connection
[ERROR] Connection failed
[INFO] Using fallback
[ERROR] No fallback available
EOF

    touch "$SCRATCH/logs/access.log"
    touch "$SCRATCH/logs/error.log"

    echo "append to me" > "$SCRATCH/session.log"

    echo "The terminal PLACEHOLDER worked." > "$SCRATCH/vim-test.txt"
}

# ─────────────────────────────────────────────────────────────────────────────
# Task text
# ─────────────────────────────────────────────────────────────────────────────

show_task() {
    local num="$1"
    local title
    title=$(challenge_title "$num")

    echo ""
    echo "[$num/11] $title"
    hr

    case "$num" in
        1)
            cat <<TASK
Navigate to $SCRATCH/project/src/ and create a file named main.c there.
TASK
            ;;
        2)
            cat <<TASK
Inside $SCRATCH/project/src/, copy original.txt to backup.txt.
Then rename backup.txt to backup.txt.bak and delete original.txt.
TASK
            ;;
        3)
            cat <<TASK
Create $SCRATCH/greet.sh containing a shebang line and a command that
outputs the word 'hello'. Make the file executable and run it.
TASK
            ;;
        4)
            cat <<TASK
Find all lines containing the word ERROR in $SCRATCH/logs/app.log
and save them to $SCRATCH/errors.txt.
TASK
            ;;
        5)
            cat <<TASK
Find all .log files anywhere under $SCRATCH/ and save a sorted list
of their paths to $SCRATCH/logfiles.txt.
TASK
            ;;
        6)
            cat <<TASK
Read $SCRATCH/logs/app.log, find lines with ERROR, sort them, remove
duplicates, and save the result to $SCRATCH/unique-errors.txt.
TASK
            ;;
        7)
            cat <<TASK
Append the line 'session closed' to the end of $SCRATCH/session.log
without overwriting its current contents.
TASK
            ;;
        8)
            # Spawn background process only on first entry to this state
            # (avoid spawning multiple times if user retries after FAIL)
            local bg_pid
            if [ ! -f "$BG_PID_FILE" ]; then
                sleep 300 &
                bg_pid=$!
                echo "$bg_pid" > "$BG_PID_FILE"
            else
                bg_pid=$(cat "$BG_PID_FILE")
            fi

            cat <<TASK
A background process is running with PID $bg_pid (will sleep for 5 minutes).
Terminate it.
TASK
            ;;
        9)
            cat <<'TASK'
Add a line to ~/.bashrc that exports a variable named F01_DONE with the
value 'yes'. Then source the file so the variable is available in your
current shell session.
TASK
            ;;
        10)
            cat <<TASK
Replace the word PLACEHOLDER with COMPLETE in $SCRATCH/vim-test.txt.

  With vim:  open the file, run :%s/PLACEHOLDER/COMPLETE/, then :wq
  With sed:  sed -i 's/PLACEHOLDER/COMPLETE/' $SCRATCH/vim-test.txt
TASK
            ;;
        11)
            cat <<'TASK'
Install NetHack on your system if you do not have it already.
TASK
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Verify challenge
# ─────────────────────────────────────────────────────────────────────────────

verify() {
    local num="$1"

    case "$num" in
        1)
            if [ -f "$SCRATCH/project/src/main.c" ]; then
                return 0
            else
                FAIL_REASON="main.c not found in project/src/"
                return 1
            fi
            ;;
        2)
            if [ -f "$SCRATCH/project/src/backup.txt.bak" ] && \
               [ ! -f "$SCRATCH/project/src/original.txt" ] && \
               [ ! -f "$SCRATCH/project/src/backup.txt" ]; then
                return 0
            else
                FAIL_REASON="Expected: backup.txt.bak present, original.txt deleted, backup.txt absent"
                return 1
            fi
            ;;
        3)
            if [ -x "$SCRATCH/greet.sh" ] && \
               "$SCRATCH/greet.sh" 2>/dev/null | grep -q 'hello'; then
                return 0
            else
                FAIL_REASON="greet.sh not executable or does not output 'hello'"
                return 1
            fi
            ;;
        4)
            if [ -f "$SCRATCH/errors.txt" ] && \
               diff "$SCRATCH/errors.txt" <(grep 'ERROR' "$SCRATCH/logs/app.log") >/dev/null; then
                return 0
            else
                FAIL_REASON="errors.txt missing or does not match expected output"
                return 1
            fi
            ;;
        5)
            if [ -f "$SCRATCH/logfiles.txt" ] && \
               diff "$SCRATCH/logfiles.txt" <(find "$SCRATCH" -name '*.log' | sort) >/dev/null; then
                return 0
            else
                FAIL_REASON="logfiles.txt missing or does not match expected output"
                return 1
            fi
            ;;
        6)
            if [ -f "$SCRATCH/unique-errors.txt" ] && \
               diff "$SCRATCH/unique-errors.txt" <(grep 'ERROR' "$SCRATCH/logs/app.log" | sort | uniq) >/dev/null; then
                return 0
            else
                FAIL_REASON="unique-errors.txt missing or does not match expected output"
                return 1
            fi
            ;;
        7)
            if head -1 "$SCRATCH/session.log" 2>/dev/null | grep -q 'append to me' && \
               tail -1 "$SCRATCH/session.log" 2>/dev/null | grep -q 'session closed'; then
                return 0
            else
                FAIL_REASON="session.log does not contain expected lines in order"
                return 1
            fi
            ;;
        8)
            if [ ! -f "$BG_PID_FILE" ]; then
                FAIL_REASON=".bg-pid missing — run ./test.sh --reset"
                return 1
            fi
            local bg_pid
            bg_pid=$(cat "$BG_PID_FILE")
            sleep 0.3
            if ! ps -p "$bg_pid" >/dev/null 2>&1; then
                return 0
            else
                FAIL_REASON="Process $bg_pid still running"
                return 1
            fi
            ;;
        9)
            if bash -i -c 'echo $F01_DONE' 2>/dev/null | grep -q 'yes'; then
                return 0
            else
                FAIL_REASON="F01_DONE not set in ~/.bashrc"
                return 1
            fi
            ;;
        10)
            if grep -q 'COMPLETE' "$SCRATCH/vim-test.txt" && \
               ! grep -q 'PLACEHOLDER' "$SCRATCH/vim-test.txt"; then
                return 0
            else
                FAIL_REASON="vim-test.txt still contains PLACEHOLDER or COMPLETE not found"
                return 1
            fi
            ;;
        11)
            if command -v nethack >/dev/null 2>&1; then
                return 0
            else
                FAIL_REASON="nethack not found in PATH"
                return 1
            fi
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Solution text
# ─────────────────────────────────────────────────────────────────────────────

solution() {
    local num="$1"

    case "$num" in
        1)
            cat <<SOLUTION
cd "$SCRATCH/project/src"
touch main.c
SOLUTION
            ;;
        2)
            cat <<SOLUTION
cd "$SCRATCH/project/src"
cp original.txt backup.txt
mv backup.txt backup.txt.bak
rm original.txt
SOLUTION
            ;;
        3)
            cat <<SOLUTION
echo '#!/bin/bash' > "$SCRATCH/greet.sh"
echo 'echo hello' >> "$SCRATCH/greet.sh"
chmod +x "$SCRATCH/greet.sh"
"$SCRATCH/greet.sh"
SOLUTION
            ;;
        4)
            cat <<SOLUTION
grep 'ERROR' "$SCRATCH/logs/app.log" > "$SCRATCH/errors.txt"
SOLUTION
            ;;
        5)
            cat <<SOLUTION
find "$SCRATCH" -name '*.log' | sort > "$SCRATCH/logfiles.txt"
SOLUTION
            ;;
        6)
            cat <<SOLUTION
cat "$SCRATCH/logs/app.log" | grep 'ERROR' | sort | uniq > "$SCRATCH/unique-errors.txt"
SOLUTION
            ;;
        7)
            cat <<SOLUTION
echo 'session closed' >> "$SCRATCH/session.log"
SOLUTION
            ;;
        8)
            local bg_pid
            bg_pid=$(cat "$BG_PID_FILE" 2>/dev/null)
            if [[ -z "$bg_pid" ]]; then
                echo "# Run ./test.sh first to start the background process, then check the PID."
            else
                cat <<SOLUTION
kill $bg_pid
SOLUTION
            fi
            ;;
        9)
            cat <<'SOLUTION'
echo 'export F01_DONE=yes' >> ~/.bashrc
source ~/.bashrc
SOLUTION
            ;;
        10)
            cat <<SOLUTION
# vim (interactive — cannot be piped to bash, run manually):
vi "$SCRATCH/vim-test.txt"
# :%s/PLACEHOLDER/COMPLETE/
# :wq

# sed (non-interactive, can be piped to bash):
sed -i 's/PLACEHOLDER/COMPLETE/' "$SCRATCH/vim-test.txt"
SOLUTION
            ;;
        11)
            cat <<'SOLUTION'
if command -v apt >/dev/null 2>&1; then
    echo "Ubuntu / Debian detected — installing nethack-console via apt"
    sudo apt install nethack-console
elif command -v brew >/dev/null 2>&1; then
    echo "Homebrew detected — installing nethack via brew"
    brew install nethack
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected but Homebrew is not installed."
    echo "Install Homebrew first: https://brew.sh"
    echo "Then run: brew install nethack"
else
    echo "Could not detect a supported package manager."
    echo "Install nethack manually (e.g. sudo apt install nethack-console)."
fi
SOLUTION
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Celebratory close for NetHack
# ─────────────────────────────────────────────────────────────────────────────

celebrate() {
    echo ""
    echo "════════════════════════════════════════════"
    echo ""
    echo "The terminal ran Rogue in 1980."
    echo "It runs NetHack now."
    echo "It will run your raycaster in a few chapters,"
    echo "and eventually a 3D engine on Dreamcast hardware."
    echo ""
    echo "The tool has not changed."
    echo "What you do with it has."
    echo ""
    echo "════════════════════════════════════════════"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

# Handle --help
if [[ "$1" = "--help" || "$1" = "-h" ]]; then
    cat <<'HELP'
Usage: ./test.sh [OPTION]

  (no arguments)        Run the tester. Verifies the current challenge and
                        advances to the next one on success.

  --solution <N>        Print the solution for challenge N (1-11).
                        Pipe to bash to apply it automatically:
                          ./test.sh --solution 2 | bash
                        Note: challenge 8 requires the test to be running
                        first (the PID must exist). Challenge 10 includes a
                        vim step that cannot be piped — use sed instead.

  --reset               Wipe all progress and start from challenge 1.

  --help, -h            Show this message.

Scratch directory: determined at runtime via XDG_RUNTIME_DIR or /tmp,
namespaced per user so parallel runs on shared machines do not collide.
HELP
    exit 0
fi

# Handle --solution flag: show solution for a specific challenge
if [[ "$1" = "--solution" ]]; then
    if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 11 ]; then
        echo "Usage: ./test.sh --solution <N>  (where N is 1-11)"
        exit 1
    fi
    solution "$2"
    exit 0
fi

# Handle --reset
if [[ "$1" = "--reset" ]]; then
    if [ -f "$BG_PID_FILE" ]; then
        kill "$(cat "$BG_PID_FILE")" 2>/dev/null
    fi
    rm -rf "$SCRATCH"
    echo "Reset. Run ./test.sh to start from challenge 1."
    exit 0
fi

# Reject unknown flags
if [[ -n "$1" ]]; then
    echo "Unknown option: $1"
    echo "Run ./test.sh --help for usage."
    exit 1
fi

# Fresh run: no SCRATCH directory
if [ ! -d "$SCRATCH" ]; then
    setup_fixtures
    echo "1" > "$STATE_FILE"
    banner
    show_task 1
    echo ""
    echo "Rerun ./test.sh when done."
    echo "Stuck? ./test.sh --solution 1  (pipe to bash to auto-run)"
    exit 0
fi

# Subsequent run: read state, verify, advance or fail
if [ ! -f "$STATE_FILE" ]; then
    echo "Error: state file missing. Run ./test.sh --reset"
    exit 1
fi

CURRENT_STATE=$(cat "$STATE_FILE")
if ! echo "$CURRENT_STATE" | grep -qE '^[0-9]+$' || \
   [ "$CURRENT_STATE" -lt 1 ] || [ "$CURRENT_STATE" -gt 11 ]; then
    echo "Error: invalid state in $STATE_FILE (got: $CURRENT_STATE)"
    echo "Run: ./test.sh --reset"
    exit 1
fi
TITLE=$(challenge_title "$CURRENT_STATE")

banner

# Verify the current challenge
if verify "$CURRENT_STATE"; then
    # PASS
    echo -e "${C_GREEN}✓ PASS${C_RESET}  [$CURRENT_STATE/11] $TITLE"

    if [ "$CURRENT_STATE" -eq 11 ]; then
        # Final celebration
        celebrate
        rm -rf "$SCRATCH"
        exit 0
    else
        # Advance to next challenge
        NEXT_STATE=$((CURRENT_STATE + 1))
        echo "$NEXT_STATE" > "$STATE_FILE"
        show_task "$NEXT_STATE"
        echo ""
        echo "Rerun ./test.sh when done."
        echo "Stuck? ./test.sh --solution $NEXT_STATE  (pipe to bash to auto-run)"
        exit 0
    fi
else
    # FAIL
    echo -e "${C_RED}✗ FAIL${C_RESET}  [$CURRENT_STATE/11] $TITLE"
    echo "  $FAIL_REASON"
    echo ""

    # Show the task again so user can see what to do without scrolling history
    show_task "$CURRENT_STATE"
    echo ""

    echo "Need help? Use: ./test.sh --solution $CURRENT_STATE"
    echo "Rerun ./test.sh to try again."
    exit 1
fi
