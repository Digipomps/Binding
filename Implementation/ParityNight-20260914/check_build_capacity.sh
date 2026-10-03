#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

set -euo pipefail

target="${1:-.}"
reserve_gib="${HAVEN_BUILD_RESERVE_GIB:-10}"
minimum_free_gib="${HAVEN_BUILD_MIN_FREE_GIB:-40}"
# The percentage floor is a proportional guard, not a comfort margin. On a large
# volume a 10% floor reserves close to 100 GiB, which blocks builds long before the
# machine is anywhere near full. The absolute GiB floor is what actually protects
# against running out; 5% keeps the proportional guard meaningful on small volumes
# without starving builds on large ones.
minimum_free_percent="${HAVEN_BUILD_MIN_FREE_PERCENT:-5}"

is_nonnegative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

for value in "$reserve_gib" "$minimum_free_gib" "$minimum_free_percent"; do
  if ! is_nonnegative_integer "$value"; then
    echo "ERROR: build-capacity values must be non-negative integers" >&2
    exit 64
  fi
done

df_line="$(df -Pk "$target" | awk 'NR == 2 { print $2, $4 }')"
read -r total_kib available_kib <<<"$df_line"
if ! is_nonnegative_integer "${total_kib:-}" || ! is_nonnegative_integer "${available_kib:-}" || (( total_kib == 0 )); then
  echo "ERROR: could not read filesystem capacity for $target" >&2
  exit 74
fi

kib_per_gib=1048576
reserve_kib=$((reserve_gib * kib_per_gib))
minimum_free_kib=$((minimum_free_gib * kib_per_gib))
if (( available_kib > reserve_kib )); then
  projected_kib=$((available_kib - reserve_kib))
else
  projected_kib=0
fi
current_percent=$((available_kib * 100 / total_kib))
projected_percent=$((projected_kib * 100 / total_kib))

printf 'Build capacity: %.1f GiB free (%d%%); reserving %d GiB leaves %.1f GiB (%d%%).\n' \
  "$(awk -v kib="$available_kib" 'BEGIN { printf "%.1f", kib / 1048576 }')" \
  "$current_percent" \
  "$reserve_gib" \
  "$(awk -v kib="$projected_kib" 'BEGIN { printf "%.1f", kib / 1048576 }')" \
  "$projected_percent" >&2

if (( projected_kib < minimum_free_kib || projected_percent < minimum_free_percent )); then
  echo "ERROR: build blocked: projected free space must remain at or above ${minimum_free_gib} GiB and ${minimum_free_percent}%." >&2
  exit 75
fi
