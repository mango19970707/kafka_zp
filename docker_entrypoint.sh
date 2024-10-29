#!/bin/bash
set -e

cd /opt/kafka/config

# step 1. 修改zookeeper配置(从KAFKA_ZOOKEEPER_CONNECT配置中提取IP字符串，转化为zookeeper集群配置)
# KAFKA_ZOOKEEPER_CONNECT示例：127.0.0.1:2181,127.0.0.2:2181,127.0.0.3:2181
# zookeeper集群配置（2888端口号是zookeeper服务之间通信的端口，3888端口是zookeeper与其他应用程序通信的端口）
# server.1=127.0.0.1:2888:3888
# server.2=127.0.0.2:2888:3888
# server.3=127.0.0.3:2888:3888
if ! grep -q "^tickTime=" "zookeeper.properties"; then # 心跳的时间间隔
    echo "tickTime=3000" >> zookeeper.properties
fi
if ! grep -q "^initLimit=" "zookeeper.properties"; then
    echo "initLimit=10" >> zookeeper.properties
fi
if ! grep -q "^syncLimit=" "zookeeper.properties"; then
    echo "syncLimit=5" >> zookeeper.properties
fi
if ! grep -q "^quorumListenOnAllIPs=" "zookeeper.properties"; then
    echo "quorumListenOnAllIPs=true" >> zookeeper.properties
fi
count=1
IFS=',' read -ra servers <<< "${KAFKA_ZOOKEEPER_CONNECT}"
for server in "${servers[@]}"; do
  if ! grep -q "^server.$count=${server/:2181/:2888:3888}" "zookeeper.properties"; then
    echo "server.$count=${server/:2181/:2888:3888}" >> zookeeper.properties
  fi
  ((count++))
done

# step 2. 启动 zookeeper
/opt/kafka/bin/zookeeper-server-start.sh -daemon /opt/kafka/config/zookeeper.properties

# step 3. 创建admin用户
/opt/kafka/bin/kafka-configs.sh --zookeeper 127.0.0.1:2181 --alter --add-config 'SCRAM-SHA-256=[password=Sw@123456],SCRAM-SHA-512=[password=Sw@123456]' --entity-type users --entity-name admin

# step 4. 添加admin-jaas配置文件
cat > kafka_server_jaas.conf << EOF
KafkaServer {
    org.apache.kafka.common.security.scram.ScramLoginModule required
    username="admin"
    password="Sw@123456";
};
EOF

cat > kafka_client_scram_admin_jaas.conf << EOF
KafkaClient {
    org.apache.kafka.common.security.scram.ScramLoginModule required
    username="admin"
    password="Sw@123456";
};
EOF

# step 5. 启动加载jaas配置文件
export KAFKA_OPTS=" -Djava.security.auth.login.config=/opt/kafka/config/kafka_server_jaas.conf"

# step 6. 配置server.properties
if ! grep -q "^broker.id=" "server.properties"; then
    echo "broker.id=${KAFKA_BROKER_ID:=0}" >> server.properties
else
    sed -i "s/^broker.id=[0-9]\+/broker.id=${KAFKA_BROKER_ID:=1}/" server.properties
fi

if ! grep -q "^listeners=" "server.properties"; then
    echo "listeners=${KAFKA_LISTENERS:=SASL_PLAINTEXT://:9092}" >> server.properties
else
    sed -i "s|^listeners=.*$|listeners=${KAFKA_LISTENERS:=SASL_PLAINTEXT://:9092}|" server.properties
fi

if ! grep -q "^advertised.listeners=" "server.properties"; then
    echo "advertised.listeners=${KAFKA_ADVERTISED_LISTENERS:=SASL_PLAINTEXT://localhost:9092}" >> server.properties
else
    sed -i "s|^advertised.listeners=.*$|advertised.listeners=${KAFKA_ADVERTISED_LISTENERS:=SASL_PLAINTEXT://localhost:9092}|" server.properties
fi

if ! grep -q "^security.inter.broker.protocol=" "server.properties"; then
    echo "security.inter.broker.protocol=SASL_PLAINTEXT" >> server.properties
fi

if ! grep -q "^sasl.mechanism.inter.broker.protocol=" "server.properties"; then
    echo "sasl.mechanism.inter.broker.protocol=SCRAM-SHA-256" >> server.properties
fi

if ! grep -q "^sasl.enabled.mechanisms=" "server.properties"; then
    echo "sasl.enabled.mechanisms=SCRAM-SHA-256,SCRAM-SHA-512" >> server.properties
fi

if ! grep -q "^allow.everyone.if.no.acl.found=" "server.properties"; then
    echo "allow.everyone.if.no.acl.found=true" >> server.properties
fi

if ! grep -q "^super.users=" "server.properties"; then
    echo "super.users=User:admin" >> server.properties
fi

if ! grep -q "^authorizer.class.name=" "server.properties"; then
    echo "authorizer.class.name=kafka.security.authorizer.AclAuthorizer" >> server.properties
fi

if ! grep -q "^zookeeper.connect=" "server.properties"; then
    echo "zookeeper.connect=${KAFKA_ZOOKEEPER_CONNECT:=localhost:2181}" >> server.properties
else
    sed -i "s/^zookeeper.connect=.*$/zookeeper.connect=${KAFKA_ZOOKEEPER_CONNECT:=localhost:2181}/" server.properties
fi

# step 7. 创建配置文件command_config.properties
cat > command_config.properties << EOF
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="Sw@123456";
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
EOF

# step 8. 启动kafka
exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties