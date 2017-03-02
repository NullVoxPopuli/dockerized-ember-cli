# dockerized-ember-cli
dockerized dev environment for ember-cli apps

When running `ember generate` or other commands that create files in the container environment, they are not owned by root. (A problem I had with other ember-cli docker images)

Includes:
 - ember
 - npm
 - bower
 - phantomjs
 - watchman
 
 The internal app directory is `/web`, so keep that in mind for your docker-compose setups.
 
 Once built, be sure to run `npm install` in the context of the container before running your ember dev-server. :-)


## Example docker-compose.yml

```yml
version: "2"
services:
  # for development only
  server:
    image: nullvoxpopuli/ember-cli
    command: bash -c "ember server"
    ports:
      - 4200:4200
      - 49152:49152

    volumes:
      - .:/web

    # ember deploy production / ember deploy staging
    # change / create this to deploy - be sure to have .env specified in .gitignore
    env_file:
      - .env
```      
