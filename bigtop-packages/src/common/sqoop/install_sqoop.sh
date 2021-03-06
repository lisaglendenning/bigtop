#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to sqoopdist.dir
     --prefix=PREFIX             path to install into
     --extra-dir=DIR             path to Bigtop distribution files

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/sqoop]
     --lib-dir=DIR               path to install sqoop home [/usr/lib/sqoop]
     --installed-lib-dir=DIR     path where lib-dir will end up on target system
     --bin-dir=DIR               path to install bins [/usr/bin]
     --conf-dir=DIR              path to configuration files provided by the package [/etc/sqoop/conf.dist]
     --examples-dir=DIR          path to install examples [doc-dir/examples]
     --initd-dir=DIR             path to install init scripts [/etc/init.d]
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'doc-dir:' \
  -l 'lib-dir:' \
  -l 'conf-dir:' \
  -l 'installed-lib-dir:' \
  -l 'bin-dir:' \
  -l 'examples-dir:' \
  -l 'build-dir:' \
  -l 'extra-dir:' \
  -l 'initd-dir:' \
  -l 'dist-dir:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
set -ex
while true ; do
    case "$1" in
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
        ;;
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --examples-dir)
        EXAMPLES_DIR=$2 ; shift 2
        ;;
        --extra-dir)
        EXTRA_DIR=$2 ; shift 2
        ;;
        --initd-dir)
        INITD_DIR=$2 ; shift 2
        ;;
        --dist-dir)
        DIST_DIR=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in PREFIX BUILD_DIR ; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

DOC_DIR=${DOC_DIR:-/usr/share/doc/sqoop}
LIB_DIR=${LIB_DIR:-/usr/lib/sqoop}
BIN_DIR=${BIN_DIR:-/usr/lib/sqoop/bin}
ETC_DIR=${ETC_DIR:-/etc/sqoop}
MAN_DIR=${MAN_DIR:-/usr/share/man/man1}
CONF_DIR=${CONF_DIR:-${ETC_DIR}/conf.dist}
INITD_DIR=${INITD_DIR:-/etc/init.d}
DIST_DIR=${DIST_DIR:-dist/target/sqoop-*}

install -d -m 0755 ${PREFIX}/${LIB_DIR}
install -d -m 0755 ${PREFIX}/${LIB_DIR}/client-lib
install -d -m 0755 ${PREFIX}/${BIN_DIR}
install -d -m 0755 ${PREFIX}/${CONF_DIR}
install -d -m 0755 ${PREFIX}/etc/default
install -d -m 0755 ${PREFIX}/var/lib/sqoop

install -m 0644 ${DIST_DIR}/client/lib/*.jar ${PREFIX}/${LIB_DIR}/client-lib/
install -m 0755 ${DIST_DIR}/bin/sqoop.sh ${PREFIX}/${BIN_DIR}/

install -m 0644 ${DIST_DIR}/server/conf/sqoop_bootstrap.properties ${PREFIX}/${CONF_DIR}
install -m 0644 ${EXTRA_DIR}/sqoop.properties ${PREFIX}/${CONF_DIR}
install -m 0644 ${EXTRA_DIR}/sqoop.default ${PREFIX}/etc/default/sqoop-server
rm ${EXTRA_DIR}/sqoop.default # Otherwise debhelper will re-install this

install -m 0755 ${DIST_DIR}/server/bin/setenv.sh ${PREFIX}/${CONF_DIR}/
sed -i -e 's#-Dsqoop.config.dir=.*conf#-Dsqoop.config.dir=/etc/sqoop/conf#' ${PREFIX}/${CONF_DIR}/setenv.sh
ln -s ${CONF_DIR}/setenv.sh ${PREFIX}/${BIN_DIR}/

# Explode the WAR
SQOOP_WEBAPPS=${PREFIX}/${LIB_DIR}/webapps
cp -r ${DIST_DIR}/server/webapps $SQOOP_WEBAPPS
unzip -d $SQOOP_WEBAPPS/sqoop $SQOOP_WEBAPPS/sqoop.war

# Create MR2 configuration
DEPLOYMENT_DIR=/etc/sqoop/conf.dist/tomcat-deployment
install -d -m 0755 ${PREFIX}/${DEPLOYMENT_DIR}/conf
for conf in web.xml tomcat-users.xml server.xml logging.properties context.xml catalina.policy
do
    install -m 0644 ${DIST_DIR}/server/conf/$conf ${PREFIX}/${DEPLOYMENT_DIR}/conf/
done
sed -i -e "s|<Host |<Host workDir=\"/var/tmp/sqoop\" |" ${PREFIX}/${DEPLOYMENT_DIR}/conf/server.xml
sed -i -e "s|\${catalina\.base}/logs|/var/log/sqoop|"   ${PREFIX}/${DEPLOYMENT_DIR}/conf/logging.properties
cp -f ${EXTRA_DIR}/catalina.properties ${PREFIX}/${DEPLOYMENT_DIR}/conf/catalina.properties

# Create wrapper scripts for the client and server
client_wrapper=$PREFIX/usr/bin/sqoop
server_wrapper=$PREFIX/usr/bin/sqoop-server
mkdir -p $PREFIX/usr/bin
install -m 0755 $EXTRA_DIR/sqoop.sh $client_wrapper
install -m 0755 $EXTRA_DIR/sqoop-server.sh $server_wrapper

