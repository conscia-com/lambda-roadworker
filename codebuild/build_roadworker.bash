#!/bin/bash
#
# Installs roadworker in /var/task/
#
source /var/task/rvm/scripts/rvm

bash ruby-env/install_ruby.bash

cd /var/task
bash /tmp/cleanup.bash
