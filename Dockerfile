FROM ruby:3.2.1

ENV BUNDLER_VERSION=2.4.6

RUN apt-get update -qq
RUN apt-get install -y \

  # Buildchain Essentials
  build-essential \
  libvips

RUN gem install bundler

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . ./
EXPOSE 3000

# ENTRYPOINT ["./entrypoints/docker-entrypoint.sh"]
CMD ["/bin/sh"]
