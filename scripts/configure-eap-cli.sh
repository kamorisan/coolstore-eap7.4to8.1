#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

EAP_HOME=/Users/kamori/vscode/developer-lightspeed/JBossEAP/jboss-eap-7.4
POSTGRES_JAR=/Users/kamori/vscode/developer-lightspeed/JBossEAP/postgresql-42.7.3.jar

echo "=== EAP CLI セットアップスクリプト ==="
echo "注意: このスクリプトを実行する前に、EAPサーバーが起動していることを確認してください"
echo ""

# CLIコマンドを実行
$EAP_HOME/bin/jboss-cli.sh --connect << EOF
# JMSトピックの追加
jms-topic add --topic-address=orders --entries=[/topic/orders]

# PostgreSQLモジュールの追加
module add --name=org.postgres --resources=$POSTGRES_JAR --dependencies=javax.api,javax.transaction.api

# JDBCドライバの追加
/subsystem=datasources/jdbc-driver=postgres:add(driver-module-name=org.postgres, driver-name=postgres)

# データソースの追加
data-source add --name=postgresDS --jndi-name=java:jboss/datasources/CoolstoreDS --driver-name=postgres --connection-url=jdbc:postgresql://localhost:5432/postgres --user-name=postgres --password=postgres

# データソースの有効化
data-source enable --name=postgresDS

# アプリケーションのデプロイ
deploy $APP_DIR/target/ROOT.war

exit
EOF

echo ""
echo "=== セットアップ完了 ==="
echo "アプリケーションは http://localhost:8080/ でアクセス可能です"
