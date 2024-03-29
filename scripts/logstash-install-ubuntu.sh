#!/bin/bash
#
# ========================================================================================
# Microsoft patterns & practices (http://microsoft.com/practices)
# SEMANTIC LOGGING APPLICATION BLOCK
# ========================================================================================
#
# Copyright (c) Microsoft.  All rights reserved.
# Microsoft would like to thank its contributors, a list
# of whom are at http://aka.ms/entlib-contributors
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You may
# obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#

help()
{
    echo ""
    echo ""
    echo "This script installs Logstash 1.4.2 on Ubuntu, and configures it to be used with user plugins/configurations"
    echo "Parameters:"
    echo "e - The encoded configuration string."
    echo ""
    echo ""
    echo ""
}

log()
{
    echo "$1"
}

#Loop through options passed
while getopts :e:hsa:k:t:i: optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    s)  #skip common install steps
      SKIP_COMMON_INSTALL="YES"
      ;;
    h)  #show help
      help
      exit 2
      ;;
    e)  #set the encoded configuration string
      log "Setting the encoded configuration string"
      CONF_FILE_ENCODED_STRING="${OPTARG}"
      ;;
    a)
      STORAGE_ACCOUNT_NAME=${OPTARG}
      ;;
    k)
      STORAGE_ACCOUNT_KEY=${OPTARG}
      ;;
    t)
      STORAGE_ACCOUNT_TABLES=${OPTARG}
      ;;
    i)
      ES_CLUSTER_IP=${OPTARG}
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

# Install Logstash


if [ -z $SKIP_COMMON_INSTALL ] 
then

    # Install Utilities
    log "Installing utilities." 
    sudo apt-get update
    sudo apt-get -y --force-yes install python-software-properties debconf-utils

    # Install Java
    log "Installing Java." 
    sudo add-apt-repository -y ppa:webupd8team/java
    sudo apt-get update
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
    sudo apt-get install -y --force-yes oracle-java8-installer

else
  log "Skipping common install"
fi

# Install Logstash
# Download and install the Public Signing Key:
log "Installing Logstash."
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
# Add the repository definition to your /etc/apt/sources.list file:
echo "deb http://packages.elastic.co/logstash/2.3/debian stable main" | sudo tee -a /etc/apt/sources.list
# Get latest package information:
sudo apt-get update
# Install logstash package:
sudo apt-get -y --force-yes install logstash

# Install Azure WAD Table Plugin
#log "Installing Azure WAD Table Plugin"
#sudo /opt/logstash/bin/logstash-plugin install logstash-input-azurewadtable

# Install Azure storage blob Plugin
log "Installing Azure WAD Table Plugin"
sudo /opt/logstash/bin/logstash-plugin install logstash-input-azurewadtable

# Install User Configuration from encoded string
if [ ! $CONF_FILE_ENCODED_STRING = "na" ] 
then
  log "Decoding configuration string"
  log "$CONF_FILE_ENCODED_STRING"
  echo $CONF_FILE_ENCODED_STRING > logstash.conf.encoded
  DECODED_STRING=$(base64 -d logstash.conf.encoded)
  log "$DECODED_STRING"
  echo $DECODED_STRING > ~/logstash.conf
else
    log "Generating Logstash Config"
    echo "input {" > ~/logstash.conf
    log "Using specified blob names"
    echo "azureblob {storage_account_name => '$STORAGE_ACCOUNT_NAME' storage_access_key => '$STORAGE_ACCOUNT_KEY' container => '$STORAGE_ACCOUNT_Container' codec => line}" >> ~/logstash.conf
    echo "}" >> ~/logstash.conf
    echo "output {elasticsearch {hosts => ['$ES_CLUSTER_IP:9200'] index => 'iis'}}" >> ~/logstash.conf
    cat ~/logstash.conf
fi

log "Installing user configuration file"
sudo \cp -f ~/logstash.conf /etc/logstash/conf.d/

# Configure Start
log "Configure start up service"
sudo update-rc.d logstash defaults 95 10
sudo service logstash start
