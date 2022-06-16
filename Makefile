# ## Build webapp image
# build:
# 	@[ "${CURRENT_TAG}" ] || echo "no tag found at commit ${COMMIT}"
# 	@[ "${CURRENT_TAG}" ] && docker build --no-cache --tag le-portail-website:${CURRENT_TAG} .
#
# ## Tag webapp image
# tag:
# 	@[ "${CURRENT_TAG}" ] || echo "no tag found at commit ${COMMIT}"
# 	@[ "${CURRENT_TAG}" ] && docker tag le-portail-website:${CURRENT_TAG} rg.fr-par.scw.cloud/le-portail/website:${CURRENT_TAG}
#
# ## Push webapp image to scaleway repository
# push:
# 	@[ "${CURRENT_TAG}" ] || echo "no tag found at commit ${COMMIT}"
# 	@[ "${CURRENT_TAG}" ] && docker push rg.fr-par.scw.cloud/le-portail/website:${CURRENT_TAG}
#
# ## Build, Tag, then Push image at ${tag} version
# publish: build tag push

## Start, then log website stack locally
up:
	docker-compose up --detach
	docker-compose logs --follow webserver wordpress

## Start, then log website stack locally, but force build first (without --no-cache option)
up-with-build:
	docker-compose up --build --detach
	docker-compose logs --follow webserver wordpress

configure:
	$(WORDPRESS_TOOLBOX) configure

## Stop local website stack
down:
	docker-compose down --volumes

enter:
	docker-compose exec wordpress bash

# ---------------------------------------------------------------------------- #

SQL_FILE := init.sql

## Backups database in its development version
database-backup:
	docker-compose exec db sh -c "mysqldump --no-tablespaces -u docker -pdocker wordpress > ${SQL_FILE}"
	docker cp $(shell docker-compose ps -q db):/${SQL_FILE} backups/${SQL_FILE}

## Backups database from its development version
database-restore:
	docker cp backups/${SQL_FILE} $(shell docker-compose ps -q db):/${SQL_FILE}
	docker-compose exec db sh -c "mysql -u docker -pdocker wordpress < ${SQL_FILE}"

## Install mkcert for self-signed certificates generation
certificates-install-mkcert:
	sudo apt install --yes libnss3-tools
	sudo wget -O /usr/local/bin/mkcert "https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-amd64" && chmod +x /usr/local/bin/mkcert
	mkcert -install

## Generate self-signed certificates
certificates-generate:
	mkcert -cert-file nginx-conf/certificates/feudebresse-cert.pem -key-file nginx-conf/certificates/feudebresse-key.pem www.feudebresse.localhost
	chmod 0644 nginx-conf/certificates/feudebresse-key.pem

WORDPRESS_TOOLBOX=docker-compose run --rm toolbox

SHELL := /bin/bash
ONESHELL:

## permanent variables
PROJECT			?= github.com/gpenaud/website-le-portail
RELEASE			?= $(shell git describe --tags --abbrev=0)
CURRENT_TAG ?= $(shell git describe --exact-match --tags 2> /dev/null)
COMMIT			?= $(shell git rev-parse --short HEAD)
BUILD_TIME  ?= $(shell date -u '+%Y-%m-%d_%H:%M:%S')

## Colors
COLOR_RESET       = $(shell tput sgr0)
COLOR_ERROR       = $(shell tput setaf 1)
COLOR_COMMENT     = $(shell tput setaf 3)
COLOR_TITLE_BLOCK = $(shell tput setab 4)

## display this help text
help:
	@printf "\n"
	@printf "${COLOR_TITLE_BLOCK}${PROJECT} Makefile${COLOR_RESET}\n"
	@printf "\n"
	@printf "${COLOR_COMMENT}Usage:${COLOR_RESET}\n"
	@printf " make build\n\n"
	@printf "${COLOR_COMMENT}Available targets:${COLOR_RESET}\n"
	@awk '/^[a-zA-Z\-_0-9@]+:/ { \
				helpLine = match(lastLine, /^## (.*)/); \
				helpCommand = substr($$1, 0, index($$1, ":")); \
				helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
				printf " ${COLOR_INFO}%-15s${COLOR_RESET} %s\n", helpCommand, helpMessage; \
		} \
		{ lastLine = $$0 }' $(MAKEFILE_LIST)
	@printf "\n"
