FROM node:7.9.0

# Note: npm is v2.15.11
RUN \
  apt-get install tar bzip2 && \
  npm install -g ember-cli@2.13.3 && \
  npm install -g bower@1.8.0 && \
  echo '{ "allow_root": true }' > /root/.bowerrc && \
  npm install -g phantomjs-prebuilt@2.1.14 && \
  npm install -g yarn && \
  # install watchman
  # Note: See the README.md to find out how to increase the
  # fs.inotify.max_user_watches value so that watchman will
  # work better with ember projects.
  git clone https://github.com/facebook/watchman.git && \
  cd watchman && \
  git checkout v3.5.0 && \
  ./autogen.sh && \
  ./configure && \
  make && \
  make install

# Ensures that the installed executables are in the path
ENV PATH "$PATH:/usr/local/lib/node_modules"

# ember server on port 4200
# livereload server on port 49152
EXPOSE 4200 49152

RUN mkdir /web
WORKDIR /web
# Adding should be done in the project Dockerfile
# ADD . /web

# run ember server on container start
CMD ["ember", "server"]
