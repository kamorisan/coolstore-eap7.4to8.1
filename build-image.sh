#!/bin/bash

set -e

echo "=========================================="
echo "  Coolstore EAP 7.4 コンテナイメージビルド"
echo "=========================================="
echo ""

# Maven build
echo "1. Maven ビルド実行..."
mvn clean package -DskipTests

# Check WAR file
if [ ! -f target/ROOT.war ]; then
    echo "エラー: ROOT.war が見つかりません"
    exit 1
fi
echo "   ✓ ROOT.war 作成完了"

# Build container image
echo ""
echo "2. コンテナイメージをビルド..."
podman build -t coolstore-eap74:latest -f Containerfile .

echo ""
echo "=========================================="
echo "  ビルド完了！"
echo "=========================================="
echo ""
echo "イメージ名: coolstore-eap74:latest"
echo ""
echo "次のステップ:"
echo "  ローカルテスト:"
echo "    ./run-local-container.sh"
echo ""
echo "  OpenShiftへプッシュ:"
echo "    ./push-to-openshift.sh"
echo ""
