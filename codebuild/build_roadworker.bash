#!/bin/bash
#
# Installs roadworker in /var/task/
#
source /var/task/rvm/scripts/rvm

rvm requirements run

rvm pkg install libyaml
rvm install ruby 2.3 --default

gem install roadworker -v '~> 0.5.7.beta3'

( cd /var/task ; bash /tmp/cleanup.bash )
