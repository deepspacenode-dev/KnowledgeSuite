#!/bin/sh
set -eu

INPUT=${1:-dist}
CHECKSUMS=${2:-$INPUT/SHA256SUMS.txt}

if [ ! -f "$CHECKSUMS" ]; then
  printf '%s\n' "Checksum manifest not found: $CHECKSUMS" >&2
  exit 1
fi

for archive in \
  drv-knowledge-worker-v2.0.3.oci.tar.zst \
  drv-knowledge-bookstack-v2.0.3.oci.tar.zst \
  drv-knowledge-fake-ragflow-v2.0.3.oci.tar.zst
do
  if [ ! -f "$INPUT/$archive" ]; then
    printf '%s\n' "OCI archive not found: $INPUT/$archive" >&2
    exit 1
  fi
  expected=$(awk -v name="$archive" '$2 == name { print $1; exit }' "$CHECKSUMS")
  if [ -z "$expected" ]; then
    printf '%s\n' "Checksum entry not found for $archive" >&2
    exit 1
  fi
  actual=$(sha256sum "$INPUT/$archive" | awk '{ print $1 }')
  if [ "$actual" != "$expected" ]; then
    printf '%s\n' "Checksum mismatch for $archive" >&2
    exit 1
  fi
  zstd -t "$INPUT/$archive" >/dev/null
  zstd -dc "$INPUT/$archive" | docker load
done

printf '%s\n' 'OCI archives verified and loaded.'
