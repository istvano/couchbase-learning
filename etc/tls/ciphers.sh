#!/bin/bash
# Usage: ./cipher_check.sh <hostname> <port>
# Example: ./cipher_check.sh example.com 443

# Check if hostname and port were provided as arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <hostname> <port>"
    exit 1
fi

HOST="$1"
PORT="$2"

# Retrieve the list of all ciphers known to OpenSSL.
# The ciphers are separated by colon; we convert that to space-delimited.
CIPHERS=$(openssl ciphers 'ALL' | tr ':' ' ')

echo "Testing ciphers on ${HOST}:${PORT}..."
echo "-----------------------------------------"

# Loop over each cipher in the list
for cipher in $CIPHERS; do
    # Inform which cipher is being tested
    printf "Testing %-40s: " "$cipher"
    
    # Attempt to establish a connection using the specified cipher.
    # 'echo' sends a newline to trigger the handshake completion.
    OUTPUT=$(echo | openssl s_client -connect ${HOST}:${PORT} -cipher "$cipher" 2>&1)
    
    # Check the output for an indication of a successful handshake.
    # When a connection succeeds, OpenSSL prints a line like "Cipher is ..." or similar.
    if echo "$OUTPUT" | grep -q "Cipher is"; then
        echo "Supported"
    elif echo "$OUTPUT" | grep -qi "handshake failure"; then
        echo "Not Supported (handshake failure)"
    else
        echo "Not Supported (connection error)"
    fi
done

echo "-----------------------------------------"
echo "Cipher test completed."
