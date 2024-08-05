#!/bin/bash
KEY="$KEY_PATH"
if [ -z "$KEY" ]; then
   echo "ERROR: KEY_PATH env var is expected"
   exit 5
fi

EC2_USER="ubuntu"
PUBLIC_INSTANCE_IP="$1"
PRIVATE_INSTANCE_IP="$2"
COMMAND="$3"

if [ $# -lt 1 ]; then
	echo "Please provide bastion IP address"
elif [ -n "$COMMAND" ]; then
  # Connect to the public instance, then the private instance, and run the command
  ssh -i "$KEY" "$EC2_USER@$PUBLIC_INSTANCE_IP" "ssh -i "$KEY" "$EC2_USER@$PRIVATE_INSTANCE_IP" "$COMMAND""
elif [ -n "$PRIVATE_INSTANCE_IP" ]; then
  # Connect to the public instance and then to the private instance
  ssh -t -i "$KEY" "$EC2_USER@$PUBLIC_INSTANCE_IP" "ssh -q -i "$KEY" "$EC2_USER@$PRIVATE_INSTANCE_IP""
else
  # Connect to the public instance
  ssh -q -t -i "$KEY" "$EC2_USER@$PUBLIC_INSTANCE_IP"
fi
