#!/bin/sh -e
#echo "#### Restoring Docker images..."
#for IMAGE in "opennms" "minion" "snmpd" "tomcat"
#do
#  docker image load -i "${ARTIFACT_DIRECTORY}/docker/stests-$IMAGE-docker-image"
#done
#
echo "#### Pulling OpenNMS images..."
docker pull opennms/horizon-core-web:24.0.0-rc
docker pull opennms/minion:24.0.0-rc
docker pull opennms/sentinel:24.0.0-rc

docker tag opennms/horizon-core-web:24.0.0-rc horizon
docker tag opennms/minion:24.0.0-rc minion
docker tag opennms/sentinel:24.0.0-rc sentinel

echo "#### Pulling other referenced images..."
docker pull postgres:9.5.1
docker pull spotify/kafka@sha256:cf8f8f760b48a07fb99df24fab8201ec8b647634751e842b67103a25a388981b
docker pull elasticsearch:2-alpine
docker pull elasticsearch:5-alpine
docker pull docker.elastic.co/elasticsearch/elasticsearch-oss:6.2.3
docker pull cassandra:3.11
docker pull polinux/snmpd:alpine
docker pull selenium/standalone-firefox-debug:3.141.59

echo "#### Building dependencies"
cd ~/
git clone --depth 1 https://github.com/OpenNMS/opennms-system-test-api.git -b circleci
cd opennms-system-test-api
mvn clean install -DskipTests=true

cd ~/
git clone --depth 1 https://github.com/OpenNMS/smoke-tests.git -b circleci
mvn clean install -DskipTests=true

cd ~/project
mvn -DupdatePolicy=never -DskipTests=true -DskipITs=true -P'!checkstyle' -Psmoke --projects :smoke-test --also-make install

echo "#### Executing tests"
cd ~/project/smoke-test
# Iterate through the tests instead of running a single command, since I can't find a way to make the later stop
# after the first failure
pyenv local 3.5.2
for TEST_CLASS in $(python3 ../.circleci/scripts/find-tests.py --use-class-names . | circleci tests split)
do
  echo "###### Testing: ${TEST_CLASS}"
  mvn -N -Dorg.opennms.smoketest.docker=true -DskipTests=false -DskipITs=false -DfailIfNoTests=false -Dit.test=$TEST_CLASS verify
done
