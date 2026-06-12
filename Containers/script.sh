#!/bin/bash

# Script to hit the Node server endpoint 100 times to increment the counter

SERVER_URL="http://localhost:8000"
ITERATIONS=100

echo "Starting to hit $SERVER_URL endpoint $ITERATIONS times..."
echo ""

for i in $(seq 1 $ITERATIONS); do
    curl -s "$SERVER_URL/" > /dev/null
    echo "Request $i of $ITERATIONS completed"
done

echo ""
echo "✓ All $ITERATIONS requests completed!"
echo ""
echo "Now go to Prometheus at http://localhost:9090"
echo "Query: http_requests_total"
echo "You should see your counter increment!"
