FROM instructure/ruby-passenger:2.1

USER root
RUN curl -sL https://deb.nodesource.com/setup_0.12 | bash -
RUN  apt-get update -qq \
  && apt-get install -qqy \
       nodejs \
       postgresql-client \
       libxmlsec1-dev \
       unzip \
       fontforge \
  && npm install -g gulp \
  && rm -rf /var/lib/apt/lists/*

# We will need sfnt2woff in order to build fonts
WORKDIR /root
RUN curl -O http://people.mozilla.org/~jkew/woff/woff-code-latest.zip \
  && unzip woff-code-latest.zip \
  && make \
  && cp sfnt2woff /usr/local/bin \
  && gem uninstall --all --ignore-dependencies --force bundler \
  && gem install bundler --no-document -v 1.11.2 \
  && find $GEM_HOME ! -user docker | xargs chown docker:docker

USER docker
WORKDIR /usr/src/app

ENV RAILS_ENV development
