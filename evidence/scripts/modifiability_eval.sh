#!/usr/bin/env bash
# modifiability_eval.sh - Automates the modifiability regression defect rate measurement.
# Standard baseline: Adapted from ISO/IEC 25010:2023 Modifiability sub-characteristic.
# Safe execution: Works on a throwaway git branch and rolls back changes completely.

set -euo pipefail

BRANCH_NAME="test/modifiability-eval-throwaway"
TARGET_FILE="lib/data/models/health_profile.dart"

echo "=== 1. Creating Throwaway Branch: $BRANCH_NAME ==="
git checkout -b "$BRANCH_NAME"

echo "=== 2. Injecting New Enum Value into $TARGET_FILE ==="
# Add new allergen case 'sesame' to the HealthProfile enum
python3 -c "
with open('$TARGET_FILE', 'r') as fp:
    content = fp.read()
# Mutate enum by appending sesame
mutated = content.replace('shellfish,\n', 'shellfish,\n  sesame,\n')
with open('$TARGET_FILE', 'w') as fp:
    fp.write(mutated)
"

echo "=== 3. Running Test Suite under Mutation ==="
set +e
flutter test > /tmp/modifiability_raw_output.txt 2>&1
TEST_EXIT=$?
set -e

echo "Flutter test exited with code: $TEST_EXIT"

echo "=== 4. Analyzing Build & Assertion Regressions ==="
python3 -c "
import re

content = open('/tmp/modifiability_raw_output.txt').read()
errors = re.findall(r'(lib/[^:]+\.dart):\d+:\d+: Error:', content)
unique_broken_files = sorted(set(errors))

failed_suites = re.findall(r'\[.*\] (test/.*_test\.dart):', content)
unique_failed_suites = sorted(set(failed_suites))

passed_matches = re.findall(r'\+(\d+): All tests passed!', content)
last_progress = re.findall(r'\+(\d+)(?:\s+-\d+)?:\s+', content)

print(f'Broken compilation files: {len(unique_broken_files)}')
for f in unique_broken_files:
    print(f'  - {f}')

print(f'Failed test suites: {len(unique_failed_suites)}')
"

echo "=== 5. Cleaning Up and Returning to Original State ==="
git checkout -- "$TARGET_FILE"
git checkout -
git branch -D "$BRANCH_NAME"
rm -f /tmp/modifiability_raw_output.txt
echo "Rollback complete. No changes made to main."
