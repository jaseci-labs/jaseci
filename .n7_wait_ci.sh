#!/usr/bin/env bash
# Emit each PR 7979 check as it settles; exit when none are pending.
SETTLED='.[] | select(.bucket!="pending") | "\(.name): \(.bucket)"'
PENDING='[.[] | select(.bucket=="pending")] | length'
SUMMARY='[.[].bucket] | group_by(.) | map("\(.[0])=\(length)") | join(" ")'
prev=""
for _ in $(seq 1 60); do
  cur=$(gh pr checks 7979 --repo jaseci-labs/jac --json name,bucket -q "$SETTLED" 2>/dev/null | sort)
  npend=$(gh pr checks 7979 --repo jaseci-labs/jac --json bucket -q "$PENDING" 2>/dev/null)
  if [ -n "$cur" ] || [ -n "$npend" ]; then
    printf '%s\n' "$cur" >/tmp/n7_cur2.txt
    printf '%s\n' "$prev" >/tmp/n7_prev2.txt
    comm -13 /tmp/n7_prev2.txt /tmp/n7_cur2.txt
    prev="$cur"
    if [ "$npend" = "0" ]; then
      printf 'ALL SETTLED: %s\n' "$(gh pr checks 7979 --repo jaseci-labs/jac --json bucket -q "$SUMMARY")"
      exit 0
    fi
  fi
  sleep 60
done
echo "TIMED OUT waiting for checks"
