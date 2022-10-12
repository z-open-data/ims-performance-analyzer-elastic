#!/usr/bin/env sh

echo "Copying objects required to build docker image:"

function checkRC() {
  local msg=$1
  local rc=$2
  if [ $rc -eq 0 ]
  then
    echo $msg"... ok"
  else
    echo $msg"... failed"
  fi
}

##
# replacing old sample data
rm -f ./data/*.zip
checkRC "deleting old sample data" $?

cp -rf ../imspa-sample-data/*.zip ./data/
checkRC "copying new sample data" $?
# replacing old kibana objects
rm -f ./kibana/*json
checkRC "deleting old kibana objects" $?

cp -rf ../samples/kibana/*json ./kibana/
checkRC "copying new kibana objects" $?
# replacing old logstach config
rm -f ./logstash/*.conf
checkRC "deleting old logstach config" $?

cp -rf ../samples/logstash/pipeline/*.conf ./logstash/
checkRC "copying new logstash config" $?
# elasticsearch is using index template without lifecycle settings, it should not be replaced
##
echo "Done"
