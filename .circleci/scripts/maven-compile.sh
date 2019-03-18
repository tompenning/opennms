#!/bin/bash

echo "Compile checkstyle module"
cd checkstyle || exit 1
mvn install -DupdatePolicy=never -DskipTests=true -DskipITs=true -T 1C -Dopennms.home=/opt/opennms -Dinstall.version="${INSTALL_VERSION}" || exit
cd ..

echo "Compile whole project"
mvn install -DupdatePolicy=never -DskipTests=true -DskipITs=true -T 1C -Dopennms.home=/opt/opennms -Dinstall.version="${INSTALL_VERSION}" --batch-mode -Prun-expensive-tasks || exit
mvn install -DupdatePolicy=never -DskipTests=true -DskipITs=true -T 1C -Dopennms.home=/opt/opennms -Dinstall.version="${INSTALL_VERSION}" --batch-mode -Prun-expensive-tasks -Pdefault --file opennms-full-assembly/pom.xml || exit
mvn install -DupdatePolicy=never -DskipTests=true -DskipITs=true -T 1C -Dopennms.home=/opt/opennms -Dinstall.version="${INSTALL_VERSION}" --batch-mode -Prun-expensive-tasks --non-recursive --file opennms-tools/pom.xml || exit
mvn install -DupdatePolicy=never -DskipTests=true -DskipITs=true -T 1C -Dopennms.home=/opt/opennms -Dinstall.version="${INSTALL_VERSION}" --batch-mode -Prun-expensive-tasks --file opennms-tools/centric-troubleticketer/pom.xml || exit
mvn javadoc:aggregate -DupdatePolicy=never --batch-mode -Prun-expensive-tasks || exit
