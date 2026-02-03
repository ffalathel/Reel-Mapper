#!/bin/bash
set -e

EMAIL="manual_test_user_$(date +%s)@example.com"
PASSWORD="password123"

echo "--- 1. Registering $EMAIL ---"
curl -s -X POST "http://localhost:8000/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}"
echo -e "\n"

echo "--- 2. Logging in ---"
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$EMAIL&password=$PASSWORD")
echo "Response: $LOGIN_RESPONSE"
echo -e "\n"

# Extract token using python
TOKEN=$(echo $LOGIN_RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "Failed to obtain token."
  exit 1
fi

echo "--- 3. Ingesting Save Event ---"
curl -s -X POST "http://localhost:8000/api/v1/save-events/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"source_url": "https://instagram.com/reel/123", "raw_caption": "I love Sushi"}'
echo -e "\n"

echo "Waiting 5 seconds for background worker to process..."
sleep 5

echo "--- 4. Verifying Home Feed ---"
curl -s -X GET "http://localhost:8000/api/v1/home" \
  -H "Authorization: Bearer $TOKEN"
echo -e "\n"
