# Patroni Container images

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/ParminCloud/Containers/patroni.yaml)
Minimal Patroni container images for running PostgreSQL clusters in containers (specially non-kubernetes environments).

## Available images

We are supprting latest patroni version with supported PostgreSQL versions. (17, 16, 15, 14, 13)

`ghcr.io/parmincloud/containers/patroni:<patroni_version>-pg<pg_version>`

Currently available images are:

* `ghcr.io/parmincloud/containers/patroni:4.0.6-pg17`
* `ghcr.io/parmincloud/containers/patroni:4.0.6-pg16`
* `ghcr.io/parmincloud/containers/patroni:4.0.6-pg15`
* `ghcr.io/parmincloud/containers/patroni:4.0.6-pg14`
* `ghcr.io/parmincloud/containers/patroni:4.0.6-pg13`

## Usage

Bind mount your configuration file to `/etc/patroni.yml` and run the container (Can be overritten by setting `PATRONI_CONFIG`).
and also bind mount your data directory to `/var/lib/postgresql/data`.

Do not forget to expose required ports (according to your configuration file).
default configuration file is available at [./patroni.yml](./patroni.yml).
