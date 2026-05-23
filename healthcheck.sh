#!/bin/bash

URL="http://localhost:5000/health"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "API saudavel - status HTTP: $HTTP_STATUS"
    exit 0
else
    echo "API com problema - status HTTP: $HTTP_STATUS"
    exit 1
fi
