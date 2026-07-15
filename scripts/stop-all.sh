#!/bin/bash

CONTAINER_NAME="coolstore-postgres"

echo "=========================================="
echo "  Coolstore EAP7 停止スクリプト"
echo "=========================================="
echo ""

# EAPプロセスの停止
echo "1. EAPサーバーを停止中..."
EAP_PIDS=$(ps aux | grep "standalone-full.xml" | grep -v grep | awk '{print $2}')

if [ -n "$EAP_PIDS" ]; then
    for pid in $EAP_PIDS; do
        kill $pid
        echo "   ✓ EAPプロセス ($pid) を停止しました"
    done
else
    echo "   - EAPプロセスが見つかりませんでした"
fi

# PostgreSQLコンテナの停止
echo ""
echo "2. PostgreSQLコンテナを停止中..."
if podman ps | grep -q $CONTAINER_NAME; then
    podman stop $CONTAINER_NAME
    echo "   ✓ PostgreSQLコンテナを停止しました"
else
    echo "   - PostgreSQLコンテナが実行されていません"
fi

# コンテナの削除（オプション）
read -p "PostgreSQLコンテナを削除しますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    podman rm $CONTAINER_NAME
    echo "   ✓ PostgreSQLコンテナを削除しました"
fi

echo ""
echo "=========================================="
echo "  停止完了"
echo "=========================================="
echo ""
