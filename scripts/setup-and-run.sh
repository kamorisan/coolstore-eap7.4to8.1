#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

EAP_HOME=/Users/kamori/vscode/developer-lightspeed/JBossEAP/jboss-eap-7.4

echo "=== Coolstore EAP7 セットアップと起動スクリプト ==="
echo ""

# 1. アプリケーションのビルド
echo "1. アプリケーションをビルド中..."
cd $APP_DIR
mvn clean package

if [ ! -f target/ROOT.war ]; then
    echo "エラー: WARファイルのビルドに失敗しました"
    exit 1
fi

# 2. standalone-full.xmlをEAPにコピー
echo ""
echo "2. standalone-full.xml を EAP にコピー中..."
cp $APP_DIR/standalone-full.xml $EAP_HOME/standalone/configuration/

# 3. EAPサーバーの起動
echo ""
echo "3. EAP サーバーを起動中..."
echo "   サーバーが起動したら、別のターミナルで以下のコマンドを実行してください:"
echo ""
echo "   EAP_HOME=$EAP_HOME"
echo "   \$EAP_HOME/bin/jboss-cli.sh --connect"
echo ""
echo "   その後、CLIで以下を実行:"
echo "   jms-topic add --topic-address=orders --entries=[/topic/orders]"
echo ""
echo "   PostgreSQLドライバとデータソースの設定:"
echo "   module add --name=org.postgres --resources=<PostgreSQLドライバのパス> --dependencies=javax.api,javax.transaction.api"
echo "   /subsystem=datasources/jdbc-driver=postgres:add(driver-module-name=org.postgres, driver-name=postgres)"
echo "   data-source add --name=postgresDS --jndi-name=java:jboss/datasources/CoolstoreDS --driver-name=postgres --connection-url=jdbc:postgresql://localhost:5432/postgres --user-name=postgres --password=postgres"
echo ""
echo "   最後にアプリケーションをデプロイ:"
echo "   deploy $APP_DIR/target/ROOT.war"
echo ""
echo "================================================"
echo ""

$EAP_HOME/bin/standalone.sh --server-config=standalone-full.xml
