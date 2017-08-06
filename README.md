# dockerized-ember-cli

[Image Tags on DockerHub](https://hub.docker.com/r/nullvoxpopuli/ember-cli/tags/)

Includes:
 - ember
 - npm
 - bower
 - phantomjs
 - watchman

 The internal app directory is `/web`, so keep that in mind for your docker-compose setups.

 Once built, be sure to run `npm install` in the context of the container before running your ember dev-server. :-)


## Example

#### Running `ember server`

```bash
docker-compose up
```

#### Testing

```bash
docker-compose run --rm dev ember server
```


#### Less Typing

```bash
#!/bin/bash
if [[ -n "$1" ]]; then
  echo "Running Command: $*"
  docker-compose run --rm dev $*
else
  echo "Booting Environment..."
  # make extra sure that the images are built
  docker-compose build

  # start up everything
  docker-compose up
fi
```

and then...

starting the ember server:

```bash
./run
```

testing:

```bash
./run ember server
```

be sure to `chmod +x run`

### Files

```Dockerfile
# Dockerfile
FROM nullvoxpopuli/ember-cli:2.14.1
USER root

ADD bower.json   /web/bower.json
RUN bower install
ADD package.json /web/package.json
RUN yarn install
```

```yml
# docker-compose.yml
version: "2"
services:
  # for development only
  # assets are compiled and stored on s3 for production
  dev:
    build:
      context: .
      dockerfile: ./Dockerfile
    command: bash -c "ember server --port 4300 --live-reload-port 59153"
    ports:
      - 4300:4300
      - 59153:59153
    volumes:
      # Mount the app code inside the container's `/web` directory
      # This keeps the container's dependencies tied to the container, and doesn't
      # pollute your project root
      - ./app:/web/app
      - ./config:/web/config
      - ./mirage:/web/mirage
      - ./public:/web/public
      - ./scripts:/web/scripts
      - ./tests:/web/tests
      - ./vendor:/web/vendor

      - ./.bowerrc:/web/.bowerrc
      - ./.ember-cli:/web/.ember-cli
      - ./.eslintignore:/web/.eslintignore
      - ./.eslintrc.js:/web/.eslintrc.js
      - ./bower.json:/web/bower.json
      - ./ember-cli-build.js:/web/ember-cli-build.js
      - ./package.json:/web/package.json
      - ./testem.js:/web/testem.js
      - ./yarn.lock:/web/yarn.lock

    # ember deploy production / ember deploy staging
    # change / create this to deploy
    env_file:
      - .env
    environment:
      - STRIPE_CLIENT_ID=thevalue
```
### Windows users

You will need to add `--watcher polling` in command as a parameter. it is likely that the changes of file on host machine will not correctly processed inside the docker. Changing a watchman from tracking events to polling file updates will solve the issue with live reloads.
