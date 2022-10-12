#!/bin/bash

# load (as required) data and objects into elasticsearch when the container starts, then tail the logs.

# run existing start script sans trailing tail & wait
source <(sed '$ d' /usr/local/bin/start.sh | sed '$ d' | sed '$ d')

# tools
CURL="curl -s"
SOCAT=socat

# environment
ELASTICSEARCH_URI="localhost:9200"
LOGSTASH_HTTP_URI="localhost:9600"
LOGSTASH_TCP_URI="localhost:5046"
KIBANA_URI="localhost:5601"

# Check if a server is ready by waiting for a successful response.
function is_ready() {
  local uri=$1
  local name=$2
  local limit=${3:-30}
  local counter=0
  # wait for response
  echo "* Checking if $name is up..."
  while [ ! "$($CURL $uri 2> /dev/null)" -a $counter -lt $limit ]; do
    sleep 1
    counter=$((counter+1))
    echo "* Waiting for $name to be up ($counter/$limit)"
  done
  if [ "$($CURL $uri 2> /dev/null)" ]; then return 1; fi
  echo "$name is up."
  return 0
}

# extra wait time before next action
function extra_wait() {
  local name=$1
  local wait=${2:-30}
  local counter=0
  # often even when application responds, it is still to ready
  echo "* Giving $name extra $wait seconds to finish startup..."
  while [ $counter -lt $wait ]; do
    sleep 1
    counter=$((counter+1))
    echo "* Waiting for $name to be ready ($counter/$wait)"
  done
  return 0
}

# Load export.ndjson (all objects)
function load_objects() {
  local uri=$1
  local space=$2
  local path=$3
  local export=$4
  echo "* Loading Kibana objects."
  # load export.ndjson
  $CURL -XPOST "http://$uri/s/$space/api/saved_objects/_import?overwrite=true" -H "kbn-xsrf: true" --form file=@$path$export > /dev/null || return 1
  echo "* Kibana objects loaded."
  return 0
}

# Load index template
function load_index_template() {
  local uri=$1
  local name=$2
  local path=$3
  local template=$4
  is_ready $ELASTICSEARCH_URI "Elasticsearch"
  echo "* Installing default index template."
  # do the curl requests to create index template
  $CURL -XPUT "http://$uri/_index_template/$name?pretty" -H "Content-Type: application/json" -d @$path$template > /dev/null || return 1
  echo "* Default index template installed."
  return 0
}

# Load Kibana space
function load_space() {
  local uri=$1
  local path=$2
  local space=$3
  is_ready $KIBANA_URI "Kibana"
  extra_wait "Kibana"
  echo "* Creating Kibana space."
  # do the curl requests to create kibana space
  $CURL -XPOST "http://$uri/api/spaces/space" -H "kbn-xsrf: true" -H "Content-Type: application/json" -d @$path$space > /dev/null || return 1
  echo "* Kibana space created."
  return 0
}

# Pipe data to logstash for ingesting into Elasticsearch
function load_data() {
  local ls_host=$1
  local file=$2
  [ -e "$file" ] || return 0
  extra_wait 'Logstash'
  echo "* Feeding sample data into Logstash."
  # pipe to logstash
  echo "* Loading data set '$file'."
  $SOCAT -u $file TCP4:$ls_host || return 1
}

# now elasticsearch & logstash are ready for first-time init
# check if elasticsearch has any data
echo "* Checking if first-time initialization is required."
if [ "$($CURL $ELASTICSEARCH_URI/_all)" == "{}" ]; then
  echo "* Performing first-time initialization."
  # set defaults for environmental variables
  INSTALL_SAMPLES="${INSTALL_SAMPLES:=1}"
  INSTALL_SAMPLE_DATA="${INSTALL_SAMPLE_DATA:=$INSTALL_SAMPLES}"
  INSTALL_SAMPLE_OBJECTS="${INSTALL_SAMPLE_OBJECTS:=$INSTALL_SAMPLES}"
  # set up the kibana index template and space
  if [ "$INSTALL_SAMPLES" -eq "1" -o "$INSTALL_SAMPLE_OBJECTS" -eq "1" ]; then
    # index template
    SAMPLE_TEMPLATE_PATH="/etc/elasticsearch/conf.d/"
    load_index_template $ELASTICSEARCH_URI "imspa" $SAMPLE_TEMPLATE_PATH "index-template.json" || exit 1
    # space
    SAMPLE_OBJECT_PATH="/opt/container/kibana/"
    load_space $KIBANA_URI $SAMPLE_OBJECT_PATH "kibana-space.json" || exit 1
  fi
  # load saved objects
  SAMPLE_OBJECT_PATH="/opt/container/kibana/"
  if [ "$INSTALL_SAMPLE_OBJECTS" -eq "1" ]; then
    load_objects $KIBANA_URI 'imspa' $SAMPLE_OBJECT_PATH 'export.ndjson' || exit 1
  fi
  # Possibly install the data
  SAMPLE_DATA_PATH="/opt/container/data/"
  if [ "$INSTALL_SAMPLE_DATA" -eq "1" ]; then
    # wait for logstash to start
    # set number of retries (default: 60, override using LS_CONNECT_RETRY env var)
    if ! [[ $LOGSTASH_CONNECT_RETRY =~ $re_is_numeric ]]; then LOGSTASH_CONNECT_RETRY=60; fi
    if is_ready $LOGSTASH_HTTP_URI "Logstash" $LOGSTASH_CONNECT_RETRY; then
      echo "* Logstash took too long to start. Displaying Logstash log:"
      cat /var/log/logstash/logstash-plain.log
      exit 1
    fi
    #unzip sample data
    echo "* Extracting sample data to "$SAMPLE_DATA_PATH
    unzip -q $SAMPLE_DATA_PATH*.zip -d $SAMPLE_DATA_PATH || exit 1
    # load sample data
    for file in $SAMPLE_DATA_PATH*.jsonl; do
      # load_data $LOGSTASH_TCP_URI $file $ELASTICSEARCH_URI || exit 1
      load_data $LOGSTASH_TCP_URI $file || exit 1
    done
  fi
  echo "* Sample data loading complete."
  # done first-time init
fi
# add fluentd logfile
#OUTPUT_LOGFILES+="/var/log/td-agent/td-agent.log"
# tail and wait
touch $OUTPUT_LOGFILES
tail -f $OUTPUT_LOGFILES &
wait
