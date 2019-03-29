@echo off
@setlocal
set startTime=%time%
clean.pl || exit /b
compile.pl -DskipTests=true || exit /b
assemble.pl -DskipTests=true -Dopennms.home=/mnt/c/Users/jwhit/git/opennms/target/opennms || exit /b
echo
echo Start Time: %startTime%
echo Finish Time: %time%
