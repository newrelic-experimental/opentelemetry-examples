#!/bin/bash

read -p "Please enter your New Relic Account ID: " ACCOUNT_ID
read -p "Please enter your New Relic License Key: " LICENSE_KEY
read -p "Please enter your New Relic User API Key: " USER_API_KEY

echo "export NEW_RELIC_LICENSE_KEY=$LICENSE_KEY" >> ~/.bashrc
echo "export NEW_RELIC_API_KEY=$USER_API_KEY" >> ~/.bashrc
echo "export NEW_RELIC_ACCOUNT_ID=$ACCOUNT_ID" >> ~/.bashrc
echo "export NEW_RELIC_REGION=US" >> ~/.bashrc
echo ""
echo "Now run the following command to refresh your environment:"
echo ""
echo "source ~/.bashrc"

exit 0