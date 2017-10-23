#!/bin/bash

cd /var/app
echo “precompiling assets”
bundle exec rake assets:precompile RAILS_ENV=$RAILS_ENV
echo “Running db:migrate on the leader node”
bundle exec rake db:migrate
#start the rails server
bundle exec puma -C config/puma.rb
