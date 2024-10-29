ARG ORIGIN_IMG_TAG
FROM docker.servicewall.cn/alpine AS downloader

ADD https://res-download.s3.cn-northwest-1.amazonaws.com.cn/k8s/tarballs/kafka_2.13-3.7.1.tgz /opt/kafka.tgz

RUN cd /opt && tar xvzf kafka.tgz

FROM docker.servicewall.cn/origin/openjdk:11-jre-slim

COPY --from=downloader /opt/kafka_2.13-3.7.1 /opt/kafka
COPY docker_entrypoint.sh /opt/docker_entrypoint.sh

ENTRYPOINT ["/opt/docker_entrypoint.sh"]
