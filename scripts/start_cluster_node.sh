#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <node_name> <cookie> [seed_node] [port]"
  echo "example: $0 keyimg1 keyimg-cookie"
  echo "example: $0 keyimg2 keyimg-cookie keyimg1@127.0.0.1 4001"
  exit 1
fi

NODE_NAME="$1"
COOKIE="$2"
SEED_NODE="${3:-}"
PORT="${4:-4000}"

FULL_NODE="${NODE_NAME}@127.0.0.1"

if [[ -n "$SEED_NODE" ]]; then
  PORT="$PORT" iex --name "$FULL_NODE" --cookie "$COOKIE" -S mix run -e "Node.connect(:'$SEED_NODE'); Process.sleep(:infinity)"
else
  PORT="$PORT" iex --name "$FULL_NODE" --cookie "$COOKIE" -S mix run -e "Process.sleep(:infinity)"
fi
