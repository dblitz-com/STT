#!/bin/bash
# User data script for bastion host webhook server setup
# This script configures the bastion host with webhook automation

set -e

# Update the GitHub App token generation script with correct installation ID
cat > /opt/webhook/github-app/get-token.sh << 'EOL'
#!/bin/bash
# GitHub App Token Generation Script (Fixed)
# Uses direct installation ID instead of repository lookup

set -e

APP_ID="1529020"
INSTALLATION_ID="74520528"  # Direct installation ID for dBlitz account
PRIVATE_KEY_PATH="/opt/webhook/github-app/private-key.pem"

# Generate JWT for GitHub App authentication
generate_jwt() {
    local header='{"alg":"RS256","typ":"JWT"}'
    local now=$(date +%s)
    local iat=$((now - 60))
    local exp=$((now + 600))
    
    local payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${APP_ID}\"}"
    
    local header_b64=$(echo -n "$header" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    local payload_b64=$(echo -n "$payload" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    local signature_input="${header_b64}.${payload_b64}"
    local signature=$(echo -n "$signature_input" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    echo "${header_b64}.${payload_b64}.${signature}"
}

# Get installation access token using direct installation ID
get_installation_token() {
    local jwt=$(generate_jwt)
    
    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")
    
    echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4
}

# Main execution
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "Error: Private key not found at $PRIVATE_KEY_PATH" >&2
    exit 1
fi

ACCESS_TOKEN=$(get_installation_token)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to get access token" >&2
    exit 1
fi

echo "$ACCESS_TOKEN"
EOL

chmod +x /opt/webhook/github-app/get-token.sh

echo "GitHub App token generation script updated with fixed installation ID"