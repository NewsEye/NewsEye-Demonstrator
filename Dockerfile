FROM ruby:2.5.3
MAINTAINER axel.jean-caurant@univ-lr.fr

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y \
  build-essential \
  nodejs \
  openjdk-8-jre


ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
WORKDIR /app

# Copy the main application.
COPY . ./
RUN gem install bundler && bundle install --local --jobs 8

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]