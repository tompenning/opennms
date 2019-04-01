#!/bin/bash -e

# shellcheck disable=SC2034

# Base Image Dependency
BASE_IMAGE="opennms/openjdk"
BASE_IMAGE_VERSION="1.8.0.201.b09-b1"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%S%z")"

# Horizon RPM repository config and version
VERSION="bleeding"
BUILD_NUMBER="${CIRCLE_BUILD_NUM}"
IMAGE_VERSION="${VERSION}-${BUILD_NUMBER}"

REPO_HOST="yum.opennms.org"
REPO_RELEASE="stable"
REPO_RPM="https://${REPO_HOST}/repofiles/opennms-repo-${REPO_RELEASE}-rhel7.noarch.rpm"
REPO_KEY_URL="https://${REPO_HOST}/OPENNMS-GPG-KEY"

# System Package dependencies
PACKAGES="wget
          gettext"

# OpenNMS Horizon dependencies
PACKAGES="${PACKAGES}
          rrdtool
          jicmp
          jicmp6
          jrrd2
          R-core"

#
# If you want to install packages from the official repository, add your packages here.
# By default the build system will build the RPMS in the ./rpms directory and install from here.
#
# Suggested packages to install OpenNMS Horizon packages from repository
#
ONMS_PACKAGES="opennms-core
               opennms-webapp-jetty
               opennms-webapp-hawtio
               opennms-webapp-remoting
               opennms-plugin-northbounder-jms
               opennms-plugin-protocol-cifs
               opennms-plugin-protocol-nsclient
               opennms-plugin-protocol-radius
               opennms-plugin-provisioning-dns
               opennms-plugin-provisioning-reverse-dns
               opennms-plugin-provisioning-snmp-asset
               opennms-plugin-provisioning-snmp-hardware-inventory"
