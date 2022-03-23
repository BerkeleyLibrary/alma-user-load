# =============================================================================
# Target: base
#
# The base stage scaffolds elements which are common to building and running
# the application, such as installing ca-certificates, creating the app user,
# and installing runtime system dependencies.
FROM ruby:3.0.3-slim AS base

# ------------------------------------------------------------
# Declarative metadata

# This declares that the container intends to listen on port 3000. It doesn't
# actually "expose" the port anywhere -- it is just metadata. It advises tools
# like Traefik about how to treat this container in staging/production.
EXPOSE 3000

# ------------------------------------------------------------
# Create the application user/group and installation directory

ENV APP_USER=alma
ENV APP_UID=40054

RUN groupadd --system --gid $APP_UID $APP_USER \
  && useradd --home-dir /opt/app --system --uid $APP_UID --gid $APP_USER $APP_USER

RUN mkdir -p /opt/app \
  && chown -R $APP_USER:$APP_USER /opt/app /usr/local/bundle

# ------------------------------------------------------------
# Install packages common to dev and prod.


# Get list of available packages
RUN apt-get update -qq

# Install standard packages from the Debian repository
RUN apt-get install -y --no-install-recommends \
  libpq-dev \
  patch

# ------------------------------------------------------------
# Run configuration

# All subsequent commands are executed relative to this directory.
WORKDIR /opt/app

# Run as the application user to minimize risk to the host.
USER $APP_USER

# Add binstubs to the path.
ENV PATH="/opt/app/bin:$PATH"

# If run with no other arguments, the image will start the rails server by
# default. Note that we must bind to all interfaces (0.0.0.0) because when
# running in a docker container, the actual public interface is created
# dynamically at runtime (we don't know its address in advance).
#
# Note that at this point, the rails command hasn't actually been installed
# yet, so if the build fails before the `bundle install` step below, you
# will need to override the default command when troubleshooting the buggy
# image.
# CMD ["rails", "server", "-b", "0.0.0.0"]
# ruby alma_user_load.rb -t ucpath -u 10192606,10171809
# CMD ["ruby", "/opt/app/alma_user_load.rb", "-t", "hey"]
CMD ["ruby", "/opt/app/alma_user_load.rb", "-t", "ucpath", "-u", "10192606,10171809"]

# =============================================================================
# Target: development
#
# The development stage installs build dependencies (system packages needed to
# install all your gems) along with your bundle. It's "heavier" than the
# production target.
FROM base AS development

# ------------------------------------------------------------
# Install build packages

# Temporarily switch back to root
USER root

# Install system packages needed to build gems with C extensions.
RUN apt-get install -y --no-install-recommends \
  gcc \
  make

# ------------------------------------------------------------
# Install Ruby gems

# Drop back to $APP_USER.
USER $APP_USER

# Base image ships with an older version of bundler
RUN gem install bundler --version 2.2.33

# Install gems. We don't enforce the validity of the Gemfile.lock until the
# final (production) stage.
COPY --chown=$APP_USER:$APP_USER Gemfile* ./
RUN bundle install

# Copy the rest of the codebase. We do this after bundle-install so that
# changes unrelated to the gemset don't invalidate the cache and force a slow
# re-install.
COPY --chown=$APP_USER:$APP_USER . .

# =============================================================================
# Target: production
#
# The production stage extends the base image with the application and gemset
# built in the development stage. It includes runtime dependencies (including
# test dependencies, due to quirks of our Jenkins build) but tries to minimize
# heavyweight build dependencies.
FROM base AS production

# ------------------------------------------------------------
# Configure for production

# Run the production stage in production mode.
# ENV RAILS_ENV=production

# ------------------------------------------------------------
# Copy code and installed gems

# Copy the built codebase from the dev stage
COPY --from=development --chown=$APP_USER /opt/app /opt/app
COPY --from=development --chown=$APP_USER /usr/local/bundle /usr/local/bundle

# Ensure the bundle is installed and the Gemfile.lock is synced.
RUN bundle config set frozen 'true'
RUN bundle install --local

# ------------------------------------------------------------
# Preserve build arguments

# passed in by Jenkins
ARG BUILD_TIMESTAMP
ARG BUILD_URL
ARG DOCKER_TAG
ARG GIT_BRANCH
ARG GIT_COMMIT
ARG GIT_URL

# build arguments aren't persisted in the image, but ENV values are
ENV BUILD_TIMESTAMP="${BUILD_TIMESTAMP}"
ENV BUILD_URL="${BUILD_URL}"
ENV DOCKER_TAG="${DOCKER_TAG}"
ENV GIT_BRANCH="${GIT_BRANCH}"
ENV GIT_COMMIT="${GIT_COMMIT}"
ENV GIT_URL="${GIT_URL}"