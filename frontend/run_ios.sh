#!/bin/bash
# Script to run Flutter on iPhone simulator with custom BACKEND_BASE_URL

# Set your backend URL
BACKEND_URL=${1:-http://127.0.0.1:5001}

# Get the first available iOS simulator device ID
DEVICE_ID=$(flutter devices | grep ios | grep -v "macOS" | awk '{print $2}' | head -n 1)

if [ -z "$DEVICE_ID" ]; then
    echo "No iOS simulator found. Please open Simulator first."
    exit 1
fi

echo "Running on device: $DEVICE_ID with BACKEND_BASE_URL=$BACKEND_URL"

flutter run -d $DEVICE_ID --dart-define=BACKEND_BASE_URL=$BACKEND_URL