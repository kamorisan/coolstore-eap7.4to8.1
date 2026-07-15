#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

EAP_HOME=/Users/kamori/vscode/developer-lightspeed/JBossEAP/jboss-eap-7.4
POSTGRES_JAR=/Users/kamori/vscode/developer-lightspeed/JBossEAP/postgresql-42.7.3.jar

echo "=========================================="
echo "  Coolstore EAP7 自動セットアップ"
echo "=========================================="
echo ""

# 1. PostgreSQLコンテナの起動
echo "1. PostgreSQLコンテナを起動中..."
CONTAINER_NAME="coolstore-postgres"

# 既存のコンテナをチェックして削除
if podman ps -a | grep -q $CONTAINER_NAME; then
    echo "   既存のコンテナを削除中..."
    podman rm -f $CONTAINER_NAME
fi

# PostgreSQLコンテナを起動
podman run -d \
  --name $CONTAINER_NAME \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  postgres:13

if [ $? -ne 0 ]; then
    echo "   ✗ PostgreSQLコンテナの起動に失敗しました"
    exit 1
fi

echo "   ✓ PostgreSQLコンテナ起動完了"
echo "   PostgreSQLの起動を待機中..."
sleep 5

# PostgreSQLの接続確認
for i in {1..30}; do
    podman exec $CONTAINER_NAME pg_isready -U postgres > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✓ PostgreSQLが利用可能になりました"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "   ✗ PostgreSQLの起動タイムアウト"
        exit 1
    fi
    sleep 1
done

# 2. アプリケーションのビルド
echo ""
echo "2. アプリケーションをビルド中..."
cd $APP_DIR
mvn clean package -q

if [ ! -f target/ROOT.war ]; then
    echo "   ✗ WARファイルのビルドに失敗しました"
    exit 1
fi
echo "   ✓ ビルド完了: target/ROOT.war"

# 3. EAPサーバーをバックグラウンドで起動（デフォルトのstandalone-full.xmlを使用）
echo ""
echo "3. EAPサーバーを起動中..."
$EAP_HOME/bin/standalone.sh --server-config=standalone-full.xml > /tmp/eap-startup.log 2>&1 &
EAP_PID=$!

# EAPの起動を待機（管理インターフェースが起動するのを待つ）
echo "   EAPサーバーの起動を待機中..."
for i in {1..60}; do
    if grep -q "WFLYSRV0025\|WFLYSRV0026" /tmp/eap-startup.log 2>/dev/null; then
        echo "   ✓ EAPサーバーが起動しました"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "   ✗ EAPサーバーの起動タイムアウト"
        echo "   ログを確認してください: /tmp/eap-startup.log"
        kill $EAP_PID
        exit 1
    fi
    sleep 1
done

# CLIが確実に接続できるよう少し待機
sleep 3

# 4. CLIでの設定とデプロイ
echo ""
echo "4. EAP設定とアプリケーションデプロイ中..."

# PostgreSQLモジュールの追加
if [ ! -d "$EAP_HOME/modules/org/postgres/main" ]; then
    echo "   PostgreSQLモジュールを追加中..."
    $EAP_HOME/bin/jboss-cli.sh --connect --command="module add --name=org.postgres --resources=$POSTGRES_JAR --dependencies=javax.api,javax.transaction.api" > /dev/null 2>&1
fi

# EAP設定を追加
echo "   データソースとJMS設定を追加中..."
$EAP_HOME/bin/jboss-cli.sh --connect << 'EOFCLI' 2>&1 | grep -v "が重複しています\|already exists"
# JMSトピックの追加（既に存在する場合はエラーを無視）
try
    jms-topic add --topic-address=orders --entries=[/topic/orders]
catch
    echo "JMS topic already exists, skipping..."
end-try

# JDBCドライバの追加（既に存在する場合はエラーを無視）
try
    /subsystem=datasources/jdbc-driver=postgres:add(driver-module-name=org.postgres, driver-name=postgres, driver-class-name=org.postgresql.Driver)
catch
    echo "JDBC driver already exists, skipping..."
end-try

# データソースの追加（既に存在する場合はエラーを無視）
try
    data-source add --name=postgresDS --jndi-name=java:jboss/datasources/CoolstoreDS --driver-name=postgres --connection-url=jdbc:postgresql://localhost:5432/postgres --user-name=postgres --password=postgres --enabled=true
catch
    echo "DataSource already exists, skipping..."
end-try

# サーバーをリロード
:reload

exit
EOFCLI

# リロードの完了を待機
echo "   サーバーのリロード待機中..."
for i in {1..30}; do
    $EAP_HOME/bin/jboss-cli.sh --connect --command=":read-attribute(name=server-state)" 2>/dev/null | grep -q "running" && break
    sleep 1
done

# アプリケーションのデプロイ
echo "   アプリケーションをデプロイ中..."
$EAP_HOME/bin/jboss-cli.sh --connect --command="deploy $APP_DIR/target/ROOT.war --force" 2>&1 | grep -v "^\[" | grep -v "standalone@"

if [ $? -eq 0 ]; then
    echo "   ✓ 設定とデプロイ完了"
else
    # デプロイメント状態を確認
    DEPLOY_STATUS=$($EAP_HOME/bin/jboss-cli.sh --connect --command="deployment-info" 2>/dev/null | grep ROOT.war | awk '{print $5}')
    if [ "$DEPLOY_STATUS" = "OK" ]; then
        echo "   ✓ 設定とデプロイ完了"
    else
        echo "   ✗ デプロイに失敗しました"
        echo "   EAPログを確認してください: /tmp/eap-startup.log"
        exit 1
    fi
fi

# デプロイメント状態を確認
echo ""
echo "   デプロイメント状態:"
$EAP_HOME/bin/jboss-cli.sh --connect --command="deployment-info" 2>/dev/null | grep ROOT.war

echo ""
echo "=========================================="
echo "  セットアップ完了！"
echo "=========================================="
echo ""
echo "アプリケーションURL: http://localhost:8080/"
echo ""
echo "EAPサーバーログ: /tmp/eap-startup.log"
echo "EAP管理コンソール: http://localhost:9990/"
echo ""
echo "EAPサーバーのPID: $EAP_PID"
echo ""
echo "停止する場合は以下を実行:"
echo "  kill $EAP_PID"
echo "  podman stop $CONTAINER_NAME"
echo ""
echo "または ./stop-all.sh を実行"
echo ""
