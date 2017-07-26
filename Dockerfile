FROM node:7.9.0

MAINTAINER Preston Sego
MAINTAINER Akram Mnif

USER root

ENV PATH $PATH:/usr/local/lib/node_modules

RUN `# Create web directory`                                                                             && \
     mkdir /web                                                                                          && \
                                                                                                            \
    `# Install Google Chrome Stable version`                                                             && \
     wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -                  && \
     echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
     apt-get update                                                                                      && \
     apt-get install -y google-chrome-stable                                                             && \
                                                                                                            \
    `# Install archivers`                                                                                && \
     apt-get install tar bzip2                                                                           && \
                                                                                                            \
    `# Install Ember CLI`                                                                                && \
     npm install -g ember-cli@2.13.3                                                                     && \
                                                                                                            \
    `# Install Bower`                                                                                    && \
     npm install -g bower@1.8.0                                                                          && \
                                                                                                            \
    `# Allow root use`                                                                                   && \
     echo '{ "allow_root": true }' > /root/.bowerrc                                                      && \
                                                                                                            \
    `# Install PhantomJS`                                                                                && \
     npm install -g phantomjs-prebuilt@2.1.14                                                            && \
                                                                                                            \
    `# Install watchman`                                                                                 && \
     git clone https://github.com/facebook/watchman.git                                                  && \
     cd watchman                                                                                         && \
     git checkout v4.7.0  # the latest stable release                                                    && \
     ./autogen.sh                                                                                        && \
     ./configure                                                                                         && \
     make                                                                                                && \
     make install                                                                                        && \
                                                                                                            \
    `# Cleaning up after installation`                                                                   && \
     apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*                                     

EXPOSE 4200 49152

WORKDIR /web

CMD ['ember','server']
