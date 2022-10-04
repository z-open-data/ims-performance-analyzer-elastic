FROM sebp/elk:7.15.2

MAINTAINER Viaceslavas Michalkevicius <vmichalkevicius@rocketsoftware.com>
LABEL \
      Description="Perform analytics on IMS Performance Analyzer data in Elastic."  \
      Vendor="Rocket Software" \
      Version="4.5.0"

# components to start
ENV START_DAEMON=true \
    LOGSTASH_START=1 \
    ELASTICSEARCH_START=1 \
    KIBANA_START=1

# move to a directory for working
WORKDIR /root/

# update repos and install netcat
RUN apt-get update && \
    apt-get -y install socat unzip

# clean the existing logstash configs and add our own
RUN rm -rf /etc/logstash/conf.d/*.conf
COPY /logstash/imspa-tcp-to-local-elasticsearch.conf /etc/logstash/conf.d/30-output.conf

# adding index template (docker instance is using its own template without lifecycle policy in it)
COPY /elasticsearch/imspa-index-template.json /etc/elasticsearch/conf.d/index-template.json

# enable CORS
RUN echo '\nhttp.cors.enabled: true \nhttp.cors.allow-origin: "*"\n' >> /etc/elasticsearch/elasticsearch.yml

# load sample data and dashboards
COPY /data /opt/container/data
COPY /kibana /opt/container/kibana

COPY /start.sh /usr/local/bin/_start.sh
RUN chmod +x /usr/local/bin/_start.sh
CMD /usr/local/bin/_start.sh
