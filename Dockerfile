FROM ruby:2.3

RUN apt-get update && apt-get install -qq -y build-essential nodejs libpq-dev postgresql-client-9.4 --fix-missing --no-install-recommends
RUN mkdir -p /var/app
RUN mkdir -p /var/app/tmp/pids/
WORKDIR /var/app
#COPY Gemfile Gemfile
COPY Gemfile /var/app/
COPY Gemfile.lock /var/app/

RUN bundle install
COPY . /var/app

#RUN bundle exec rake assets:precompile
EXPOSE 3000
CMD        ["./script/docker_start.sh"]
