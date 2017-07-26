FROM node:6

MAINTAINER Preston Sego
MAINTAINER Akram Mnif

USER root

ENV PATH $PATH:/usr/local/lib/node_modules

RUN  \
  # Create web directory
  mkdir /web \
  \
  # Install archivers
  && apt-get install tar bzip2 \
  \
  # Install Ember CLI
  && npm install -g ember-cli@2.14.1 \
  \
  # Install Bower
  && npm install -g bower@1.8.0 \
  \
  # Allow bower to function under the root user
  && echo '{ "allow_root": true }' > /root/.bowerrc \
  \
  # Install PhantomJS
  && npm install -g phantomjs-prebuilt@2.1.14 \
  \
  # Install watchman
  && git clone https://github.com/facebook/watchman.git \
  && cd watchman \
  && git checkout v4.7.0  # the latest stable release \
  && ./autogen.sh \
  && ./configure \
  && make \
  && make install \
  \
  # Cleaning up after installation
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 4200 49152

WORKDIR /web

CMD ['ember','server']
