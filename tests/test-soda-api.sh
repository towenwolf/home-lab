#!/bin/bash
# Test script for Oregon State Spending SODA API
# Endpoint: https://data.oregon.gov/resource/y9g9-xsxs.json

ENDPOINT="https://data.oregon.gov/resource/y9g9-xsxs.json"

echo "=== Testing Oregon State Spending SODA API ==="
echo ""

# Basic fetch - first 5 records
echo "1. Fetching first 5 records..."
curl -s "${ENDPOINT}?\$limit=5" | jq '.'

echo ""
echo "---"
echo ""

# Get record count
echo "2. Getting total record count..."
curl -s "${ENDPOINT}?\$select=count(*)" | jq '.'

echo ""
echo "---"
echo ""

# Fetch with specific columns (adjust column names after seeing schema)
echo "3. Fetching with pagination (limit=3, offset=0)..."
curl -s "${ENDPOINT}?\$limit=3&\$offset=0&\$order=:id" | jq '.'

echo ""
echo "=== Done ==="
