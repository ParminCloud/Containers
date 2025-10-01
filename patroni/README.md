# Patroni Container images

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/ParminCloud/Containers/patroni.yaml)

Minimal Patroni container images for running PostgreSQL clusters in containers (specially non-kubernetes environments).

## Available images

We are supprting latest patroni version with supported PostgreSQL versions. (18, 17, 16, 15, 14, 13)

`ghcr.io/parmincloud/containers/patroni:<patroni_version>-pg<pg_version>`

Currently available images are:

* `ghcr.io/parmincloud/containers/patroni:4.1.0-pg18`
* `ghcr.io/parmincloud/containers/patroni:4.1.0-pg17`
* `ghcr.io/parmincloud/containers/patroni:4.1.0-pg16`
* `ghcr.io/parmincloud/containers/patroni:4.1.0-pg15`
* `ghcr.io/parmincloud/containers/patroni:4.1.0-pg14`
* `ghcr.io/parmincloud/containers/patroni:4.1.0-pg13`

## Usage

Bind mount your configuration file to `/etc/patroni.yml` and run the container (Can be overritten by setting `PATRONI_CONFIG`).
and also bind mount your data directory to `/var/lib/postgresql/data`.

> [!IMPORTANT]
Data directory owner must be `999:999` (Acording to PostgreSQL container image which is our base image)  
And it's mode must be `700` or `750`  

Do not forget to expose required ports (according to your configuration file).
default configuration file is available at [./patroni.yml](./patroni.yml).

`patronictl` access can be achivied by specifing config path to `$PATRONI_CONFIG` like

```shell
patronictl -c $PATRONI_CONFIG list
```
