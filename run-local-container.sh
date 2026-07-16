#!/bin/bash

set -e

echo "=========================================="
echo "  Coolstore EAP 7.4 ローカル起動"
echo "=========================================="
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "エラー: .env ファイルが見つかりません"
    exit 1
fi

# Run container
echo "コンテナを起動中..."
podman run --rm -it \
    --name coolstore-eap74 \
    -p 8080:8080 \
    -p 9990:9990 \
    -e DB_HOST=${DB_HOST} \
    -e DB_PORT=${DB_PORT} \
    -e DB_NAME=${DB_NAME} \
    -e DB_USERNAME=${DB_USERNAME} \
    -e DB_PASSWORD=${DB_PASSWORD} \
    coolstore-eap74:latest

echo ""
echo "コンテナが停止しました"
