#!/bin/bash
# Check if the user added an instance ip
if [ $# -ne 1 ]; then
  echo "No server ip found"
  exit 1
fi
# Get the server ip from the execute command
server_public_ip="$1"
# Set the requested url
url="http://$server_public_ip:8080/clienthello"
# Json content requested to send
json=$(cat <<'EOF'
{
  "version": "1.3",
  "ciphersSuites": [
    "TLS_AES_128_GCM_SHA256",
    "TLS_CHACHA20_POLY1305_SHA256"
  ],
  "message": "Client Hello"
}
EOF
)
# Response for the post method
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json" "$url")
# Save sessionID and serverCert for later use
sessionID=$(echo "$response" | jq -r '.sessionID')
echo "sessionID is: $sessionID"
serverCert="serverCert.pem"
echo "$response" | jq -r '.serverCert' | sed 's/[[:space:]]*$//' > "$serverCert"
echo "Saved sessionID and serverCert"
echo "serverCert is: "
cat "$serverCert"
# Download CA certificate file from AWS
wget https://exit-zero-academy.github.io/DevOpsTheHardWayAssets/networking_project/cert-ca-aws.pem
certCaAws="cert-ca-aws.pem"
expectedOutput="serverCert.pem: OK"
echo "serverCert.pem"
openssl x509 -in serverCert.pem -noout -text | grep -A 1 'Key Identifier'
echo "serverCert.pem ended"
echo "aws.pem"
openssl x509 -in cert-ca-aws.pem -noout -text | grep -A 1 'Key Identifier'
echo "aws ended"
# Check the certificate validation and prints the result
validation_result=$(openssl verify -CAfile "$certCaAws" "$serverCert")
echo "$validation_result" "$expectedOutput"
if [ "$validation_result" == "$expectedOutput" ]; then
  echo "cert.pem: OK"
else
  echo "Server Certificate is invalid."
  exit 5
fi
# Generate a 32-byte random base 64 string and save it for later use
master_key_file="master_key.txt"
master_key=$(openssl rand -base64 32)
echo "$master_key" > "$master_key_file"
echo "Master key saved to master_key.txt"
# encrypt the master key
encrypted_master_key=$(openssl smime -encrypt -aes-256-cbc -in "$master_key_file" -outform DER "$serverCert" | base64 -w 0)
echo "the encrypted_master_key is $encrypted_master_key"
# Set the relevant endpoint
keyExchange_url="http://$server_public_ip:8080/keyexchange"
# Save the key exchange json
keyExchange_json=$(cat <<EOF
{
  "sessionID": "$sessionID",
  "masterKey": "$encrypted_master_key",
  "sampleMessage": "Hi server, please encrypt me and send to client!"
}
EOF
)
sampleMessage=$(echo "$keyExchange_json" | jq -r '.sampleMessage')
echo "sample message is: $sampleMessage"
# POST the key exchange json to keyexchange endpoint
keyExchange_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$keyExchange_json" "$keyExchange_url")
echo "keyExchange_response is: $keyExchange_response"
encryptedSampleMessage=$(echo "$keyExchange_response" | jq -r '.encryptedSampleMessage')
decoded_message=$(echo "$encryptedSampleMessage" | base64 -d)
echo "decoded_message is: $decoded_message"
echo "master key is: $master_key"
echo "file is $master_key_file"
decrypted_message=$(echo "$decoded_message" | openssl enc -d -aes-256-cbc -pbkdf2 -k "$master_key")
#if [ $? -ne 0 ]; then
#  echo "Decryption failed."
#  exit 7
#fi

echo "The decrypted message is: $decrypted_message"

# Trim leading and trailing whitespace
echo "$decrypted_message" | od -c
echo "$sampleMessage" | od -c
if [[ "$decrypted_message" == "$sampleMessage" ]]; then
  echo "Client-Server TLS handshake has been completed successfully"
else
  echo "Server symmetric encryption using the exchanged master-key has failed."
  exit 6
fi