#!/bin/bash
set -e

echo "Building and starting container for test..."
docker run -d --name health-test -p 8000:8000 capstone-image
sleep 4

echo "Curling /health endpoint..."
RESPONSE=$(curl -s http://localhost:8000/health)
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"ok"'; then
  echo "✅ Test passed"
  docker stop health-test && docker rm health-test
  exit 0
else
  echo "❌ Test failed"
  docker stop health-test && docker rm health-test
  exit 1
fi