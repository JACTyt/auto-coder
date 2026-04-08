#!/usr/bin/env bash

set -e

ISSUE_NUMBER=$1
REPO=$2
GITHUB_TOKEN=$3
OPENAI_API_KEY=$4

echo "Fetching issue #$ISSUE_NUMBER from $REPO..."

# Get issue body (the prompt)
ISSUE_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER)

ISSUE_BODY=$(echo "$ISSUE_RESPONSE" | jq -r .body)

echo "Issue body retrieved."

# Prepare prompt
PROMPT="You are a coding assistant. Generate code based on this request.
Return ONLY code blocks with filenames.

$ISSUE_BODY"

echo "Sending request to OpenAI..."

# Call OpenAI API
OPENAI_RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"gpt-4o-mini\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"$PROMPT\"}
    ],
    \"temperature\": 0.2
  }")

CONTENT=$(echo "$OPENAI_RESPONSE" | jq -r '.choices[0].message.content')

echo "Response received."

# Create output directory
OUTPUT_DIR="autocoder-bot"
mkdir -p "$OUTPUT_DIR"

echo "Extracting files..."

# Extract code blocks with filenames (```filename\ncode```)
echo "$CONTENT" | awk '
BEGIN { filename="" }
/^```/ {
  if (filename == "") {
    filename = substr($0, 4)
    gsub(/\r/, "", filename)
    next
  } else {
    filename=""
    next
  }
}
filename != "" {
  print >> ("autocoder-bot/" filename)
}
'

echo "Files generated in $OUTPUT_DIR:"
ls -R "$OUTPUT_DIR"