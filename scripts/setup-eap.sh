#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

EAP_HOME=/Users/kamori/vscode/developer-lightspeed/JBossEAP/jboss-eap-7.4
POSTGRES_JAR=/Users/kamori/vscode/developer-lightspeed/JBossEAP/postgresql-42.7.3.jar

echo "=== Coolstore EAP7 セットアップ ==="
echo ""

# アプリケーションのビルド
echo "1. アプリケーションをビルド中..."
cd $APP_DIR
mvn clean package

if [ ! -f target/ROOT.war ]; then
    echo "エラー: WARファイルのビルドに失敗しました"
    exit 1
fi
echo "   ✓ ビルド完了: target/ROOT.war"

# standalone-full.xmlをコピー
echo ""
echo "2. standalone-full.xml を EAP にコピー中..."
cp $APP_DIR/standalone-full.xml $EAP_HOME/standalone/configuration/
echo "   ✓ コピー完了"

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "次のステップ:"
echo "1. EAPサーバーを起動:"
echo "   cd $EAP_HOME"
echo "   ./bin/standalone.sh --server-config=standalone-full.xml"
echo ""
echo "2. 別のターミナルでCLIに接続:"
echo "   $EAP_HOME/bin/jboss-cli.sh --connect"
echo ""
echo "3. CLIで以下のコマンドを実行:"
echo "   jms-topic add --topic-address=orders --entries=[/topic/orders]"
echo "   module add --name=org.postgres --resources=$POSTGRES_JAR --dependencies=javax.api,javax.transaction.api"
echo "   /subsystem=datasources/jdbc-driver=postgres:add(driver-module-name=org.postgres, driver-name=postgres)"
echo "   data-source add --name=postgresDS --jndi-name=java:jboss/datasources/CoolstoreDS --driver-name=postgres --connection-url=jdbc:postgresql://localhost:5432/postgres --user-name=postgres --password=postgres"
echo "   deploy $APP_DIR/target/ROOT.war"
echo ""
echo "または、自動セットアップスクリプトを使用:"
echo "   ./configure-eap-cli.sh"
echo ""
