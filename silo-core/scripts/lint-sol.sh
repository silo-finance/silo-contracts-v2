#!/bin/bash

# Default values
MAX_WARNINGS="${1:-0}"
LINT_PATH="${2:-contracts/**/*.sol}"

# Show usage if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [max_warnings] [path]"
    echo "  max_warnings: Maximum number of warnings allowed (default: 0)"
    echo "  path: Path pattern to lint (default: contracts/**/*.sol)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Use default (0 warnings, contracts/**/*.sol)"
    echo "  $0 10                 # Allow up to 10 warnings, contracts/**/*.sol"
    echo "  $0 0 test/**/*.sol     # 0 warnings, lint test files"
    echo "  $0 5 contracts/**/*.sol # Allow 5 warnings, lint contracts"
    exit 0
fi

# Run solhint and capture the output
output=$(npx solhint "$LINT_PATH" --ignore-path .solhintignore --max-warnings="$MAX_WARNINGS" 2>&1)
exit_code=$?

# Extract the number of warnings from the output
warnings_line=$(echo "$output" | grep "✖.*problems.*warnings")
if [ -n "$warnings_line" ]; then
    # Extract the number of warnings using regex - format: "✖ 40 problems (0 errors, 40 warnings)"
    warnings_count=$(echo "$warnings_line" | sed -n 's/.*✖ [0-9]* problems ([0-9]* errors, \([0-9]*\) warnings).*/\1/p')
    if [ "$warnings_count" -gt "$MAX_WARNINGS" ]; then
        echo "$output"
        exit 1
    fi
fi

# If no problems found or warnings are within limit, exit with the original exit code
echo "$output"
exit $exit_code
