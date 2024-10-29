### 概述

用于构建zookeeper模式的kafka集群镜像。

### 参数说明


| name                       | type   | default        | remark         |
|----------------------------|--------|----------------|----------------|
| KAFKA_ZOOKEEPER_CONNECT    | string | 127.0.0.1:2181 | zookeeper集群节点  |
| KAFKA_BROKER_ID            | number | 1              | kafka节点ID      |
| KAFKA_ADVERTISED_LISTENERS | string | SASL_PLAINTEXT://localhost:9092 | kafka生产消费监听的端口 |



### 使用示例
```yaml
version: "3"

networks:
  sw:

services:
  kafka:
    image: docker.servicewall.cn/infra/kafka:3.7.1
    container_name: sw_kafka
    restart: always
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ADVERTISED_LISTENERS: SASL_PLAINTEXT://192.168.110.163:9092
      KAFKA_ZOOKEEPER_CONNECT: 192.168.110.88:2181,192.168.110.163:2181
    networks:
      - sw
    ports:
      - 9092:9092
      - 2888:2888 # zookeeper服务之间通信的端口
      - 3888:3888 # zookeeper与其他应用程序通信的端口
      - 2181:2181
    volumes:
      - ./kafka_data:/tmp
```