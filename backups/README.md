# Backup Container Images

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/ParminCloud/Containers/backups.yaml)

A family of small Debian based images that dump a data source (PostgreSQL, MySQL, MariaDB, MongoDB,
a local directory, or a remote host over SSH), optionally encrypt the result with GnuPG, and upload
it to an S3 bucket — either on a built-in cron schedule or as a single one-shot run driven by an
external scheduler such as a Kubernetes `CronJob`.

All variants share the same base, so the S3, encryption, scheduling and retention behaviour is
identical across images. Only the "how do I get the data" part differs.

> [!NOTE]
> Examples below use `docker run`; `podman run` accepts the same flags.

## How it works

1. The entrypoint copies the container environment into `/etc/environment` so that jobs started by
   `cron` see the same variables as PID 1.
2. `start-container` requires `S3_BUCKET`. Then:
   * `BACKUP_SCHEDULE` **empty** → run the backup **once** in the foreground and exit. This is the
     mode you want under Kubernetes and any other external scheduler.
   * `BACKUP_SCHEDULE` **set** → write `/etc/crontab` and run `cron -f` in the foreground, so the
     container stays alive and backs up on schedule.
3. Each backup run takes an exclusive `flock`, so a long run is never overlapped by the next tick
   (the second run logs `Backup already running... exiting...` and exits `1`).
4. The variant script (`$BACKUP_CMD`) writes an archive under `/tmp` and prints its path.
5. If `BACKUP_PASSWORD` is set the archive is encrypted with `gpg --symmetric` and `.gpg` is
   appended to the name.
6. The file is uploaded to `s3://$S3_BUCKET/$S3_PREFIX/<timestamp>.<extension>`, where `<timestamp>`
   is the container's local time in `%Y-%m-%dT%H:%M:%S` form — e.g.
   `s3://my-bucket/prod/pg/2026-08-23T02:00:00.sql.gz`. The original filename is not preserved, so
   the timestamp is what distinguishes one backup from the next.
7. If `BACKUP_RETENTION_DAYS` is set, objects under the prefix older than that many days are
   deleted.

Logs go to stderr with a timestamp prefix, and cron output is redirected to PID 1's stdout/stderr,
so `docker logs` / `kubectl logs` show everything.

## Available images

All variants are published under the same repository with a per-variant tag:

`ghcr.io/parmincloud/containers/backups:<tag>`

| Tag | Backs up | Uploaded object |
| --- | --- | --- |
| `file-backup` | A directory mounted into the container | `<timestamp>.tar.gz` |
| `pg13-dump` … `pg18-dump` | All PostgreSQL databases **and roles** (`pg_dumpall`) | `<timestamp>.sql.gz` |
| `pg13-basebackup` … `pg18-basebackup` | A physical PostgreSQL base backup (`pg_basebackup`) | `<timestamp>.tar.gz` |
| `mysqldump` | All MySQL databases (`mysqldump --all-databases`) | `<timestamp>.sql.gz` |
| `mariadb-dump` | All MariaDB databases (`mariadb-dump --all-databases`) | `<timestamp>.sql.gz` |
| `mongodump` | Everything reachable through a MongoDB URI (`mongodump`) | `<timestamp>.tar.gz` |
| `sshfile` | A directory on a **remote** host, over SSH | `<timestamp>.tar.gz` |
| `sshcommand` | The stdout of a remote command — network device configs, vendor CLI dumps | `<timestamp>.gz` |

PostgreSQL variants are built for 13, 14, 15, 16, 17 and 18 — replace `pg18` with the major version
matching your server. Use a client version **>=** your server version.

Images are `linux/amd64` only.

## Common environment variables

These apply to every variant.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `S3_BUCKET` | **yes** | – | Destination bucket. The container refuses to start without it. |
| `S3_PREFIX` | no | – | Key prefix inside the bucket (no leading/trailing slash). Strongly recommended — see the retention warning. |
| `BACKUP_SCHEDULE` | no | – | 5-field system cron expression (e.g. `0 2 * * *`, `@daily` also works). **Leave unset to run once and exit.** |
| `BACKUP_RETENTION_DAYS` | no | – | Delete objects under `S3_PREFIX` older than N days after a successful upload. Unset means keep forever. |
| `BACKUP_PASSWORD` | no | – | When set, the archive is symmetrically encrypted with GnuPG and gets a `.gpg` suffix. |
| `DATA_DIR` | variant | `/data` | Directory to archive. Local path for `file-backup`, **remote** path for `sshfile`. |

Credentials for S3 are read by the AWS CLI, so the standard variables apply:

| Variable | Description |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Access key. |
| `AWS_SECRET_ACCESS_KEY` | Secret key. |
| `AWS_DEFAULT_REGION` | Bucket region, e.g. `us-east-1`. |
| `AWS_ENDPOINT_URL` | Set this for S3-compatible storage (MinIO, Ceph RGW, Parmin Cloud object storage, …). |

> [!WARNING]
> `BACKUP_RETENTION_DAYS` prunes **every** object under `S3_PREFIX`, not just the ones this
> container created. With no `S3_PREFIX` set, that is the entire bucket. Always give each backup job
> its own prefix, or a dedicated bucket.

## Variants

### `file-backup` — a mounted directory

Archives `DATA_DIR` (default `/data`) as a gzipped tar, preserving ACLs and extended attributes.
Mount the data read-only where possible.

| Variable | Required | Default |
| --- | --- | --- |
| `DATA_DIR` | no | `/data` |

```shell
docker run --rm \
  -v /srv/uploads:/data:ro \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/uploads \
  -e BACKUP_SCHEDULE="0 3 * * *" \
  -e BACKUP_RETENTION_DAYS=30 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:file-backup
```

As a Compose service next to the app that owns the volume:

```yaml
services:
  uploads-backup:
    image: ghcr.io/parmincloud/containers/backups:file-backup
    restart: unless-stopped
    volumes:
      - uploads:/data:ro
    environment:
      S3_BUCKET: my-backups
      S3_PREFIX: prod/uploads
      BACKUP_SCHEDULE: "0 3 * * *"
      BACKUP_RETENTION_DAYS: "30"
      BACKUP_PASSWORD: ${BACKUP_PASSWORD}
      AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
      AWS_DEFAULT_REGION: us-east-1

volumes:
  uploads:
```

Restore:

```shell
tar -C /srv/uploads --acls --xattrs -xzpf 2026-08-23T03:00:00.tar.gz
```

### `pgXX-dump` — logical PostgreSQL dump

Runs `pg_dumpall`, so the result includes every database plus globals (roles, tablespaces).

| Variable | Required |
| --- | --- |
| `PGHOST` | **yes** |
| `PGPORT` | **yes** |
| `PGUSER` | **yes** |
| `PGPASSWORD` | **yes** |

All four are validated as non-empty, including `PGPASSWORD` — even if your server uses `trust`
authentication, pass a non-empty placeholder.

```shell
docker run --rm \
  -e PGHOST=postgres.internal \
  -e PGPORT=5432 \
  -e PGUSER=postgres \
  -e PGPASSWORD=secret \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/pg-dump \
  -e BACKUP_SCHEDULE="0 2 * * *" \
  -e BACKUP_RETENTION_DAYS=14 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:pg18-dump
```

Restore:

```shell
gunzip -c 2026-08-23T02:00:00.sql.gz | psql -h postgres.internal -U postgres -d postgres
```

### `pgXX-basebackup` — physical PostgreSQL base backup

Runs `pg_basebackup -c fast -X stream` and archives the resulting data directory. Needs a role with
the `REPLICATION` attribute and a free WAL sender slot on the server.

| Variable | Required |
| --- | --- |
| `PGHOST` | **yes** |
| `PGPORT` | **yes** |
| `PGUSER` | **yes** |
| `PGPASSWORD` | **yes** |

```shell
docker run --rm \
  -e PGHOST=postgres.internal \
  -e PGPORT=5432 \
  -e PGUSER=replicator \
  -e PGPASSWORD=secret \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/pg-basebackup \
  -e BACKUP_SCHEDULE="0 1 * * *" \
  -e BACKUP_RETENTION_DAYS=7 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:pg18-basebackup
```

> [!IMPORTANT]
> Before archiving, this variant **replaces** `pg_hba.conf` and `postgresql.conf` in the backup with
> permissive versions (`trust` for local and loopback, `md5`/`scram-sha-256` from any address, and
> `listen_addresses = '*'` on port 5432). That makes the archive easy to start as a throwaway
> restore instance, but it is **not** a safe configuration for a production server. Restore your own
> configuration files before exposing the instance to a network.

Restore into an empty data directory:

```shell
mkdir -p /var/lib/postgresql/data
tar -C /var/lib/postgresql/data --acls --xattrs -xzpf 2026-08-23T01:00:00.tar.gz
chown -R 999:999 /var/lib/postgresql/data   # uid/gid of the postgres user in your image
chmod 700 /var/lib/postgresql/data
```

### `mysqldump` — logical MySQL dump

`mysqldump --all-databases --single-transaction --triggers --routines --events`.

| Variable | Required | Default |
| --- | --- | --- |
| `MYSQL_HOST` | **yes** | – |
| `MYSQL_PORT` | **yes** | – |
| `MYSQL_USER` | **yes** | – |
| `MYSQL_PASSWORD` | **yes** | – |
| `DUMP_MODE` | no | `mysql` |

```shell
docker run --rm \
  -e MYSQL_HOST=mysql.internal \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=secret \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/mysql \
  -e BACKUP_SCHEDULE="30 2 * * *" \
  -e BACKUP_RETENTION_DAYS=14 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:mysqldump
```

The user needs at least `SELECT`, `LOCK TABLES`, `SHOW VIEW`, `EVENT` and `TRIGGER` on all schemas.

Restore:

```shell
gunzip -c 2026-08-23T02:30:00.sql.gz | mysql -h mysql.internal -u root -p
```

### `mariadb-dump` — logical MariaDB dump

Same script as `mysqldump`, but built with the MariaDB client and `DUMP_MODE=mariadb`, so it reads
the `MARIADB_*` variables instead.

| Variable | Required | Default |
| --- | --- | --- |
| `MARIADB_HOST` | **yes** | – |
| `MARIADB_PORT` | **yes** | – |
| `MARIADB_USER` | **yes** | – |
| `MARIADB_PASSWORD` | **yes** | – |
| `DUMP_MODE` | no | `mariadb` |

```shell
docker run --rm \
  -e MARIADB_HOST=mariadb.internal \
  -e MARIADB_PORT=3306 \
  -e MARIADB_USER=root \
  -e MARIADB_PASSWORD=secret \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/mariadb \
  -e BACKUP_SCHEDULE="30 2 * * *" \
  -e BACKUP_RETENTION_DAYS=14 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:mariadb-dump
```

Restore:

```shell
gunzip -c 2026-08-23T02:30:00.sql.gz | mariadb -h mariadb.internal -u root -p
```

### `mongodump` — MongoDB dump

Runs `mongodump` with one job per CPU and archives the BSON dump directory.

| Variable | Required |
| --- | --- |
| `MONGODB_URI` | **yes** |

```shell
docker run --rm \
  -e MONGODB_URI="mongodb://backup:secret@mongo.internal:27017/?authSource=admin" \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/mongo \
  -e BACKUP_SCHEDULE="0 4 * * *" \
  -e BACKUP_RETENTION_DAYS=14 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:mongodump
```

Scope the dump by putting a database in the URI path (`…:27017/mydb?authSource=admin`); the role
needs `backup` (or `read` on the target databases).

Restore — the archive holds one directory per database at its root:

```shell
mkdir restore && tar -C restore -xzpf 2026-08-23T04:00:00.tar.gz
mongorestore --uri="mongodb://…" restore
```

### `sshfile` — a directory on a remote host

Runs `tar` **on the remote host** over SSH and streams the archive back, so nothing needs to be
mounted into the container. `DATA_DIR` is a path on the remote machine.

| Variable | Required | Default |
| --- | --- | --- |
| `SSH_HOST` | **yes** | – |
| `SSH_USER` | **yes** | – |
| `DATA_DIR` | yes, default is fine | `/data` |
| `SSH_PORT` | yes, default is fine | `22` |
| `SSH_PRIVATE_KEY` | one of the three | – |
| `SSH_PASSWORD` | one of the three | – |

Authentication is picked in this order:

1. A private key bind-mounted at `/root/.ssh/id_rsa` (mode `0600`).
2. `SSH_PRIVATE_KEY` — the key material itself, added to a per-run `ssh-agent`.
3. `SSH_PASSWORD` — password auth via `sshpass`.

With a mounted key:

```shell
docker run --rm \
  -v "$HOME/.ssh/backup_key:/root/.ssh/id_rsa:ro" \
  -e SSH_HOST=app01.example.com \
  -e SSH_PORT=22 \
  -e SSH_USER=backup \
  -e DATA_DIR=/var/www/shared/storage \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/app01-storage \
  -e BACKUP_SCHEDULE="15 3 * * *" \
  -e BACKUP_RETENTION_DAYS=30 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:sshfile
```

With the key passed as an environment variable (handy for Kubernetes `Secret`s):

```shell
docker run --rm \
  -e SSH_PRIVATE_KEY="$(cat ~/.ssh/backup_key)" \
  -e SSH_HOST=app01.example.com \
  -e SSH_USER=backup \
  -e DATA_DIR=/var/www/shared/storage \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=prod/app01-storage \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:sshfile
```

Restore is the same as `file-backup`.

### `sshcommand` — output of a remote command

Runs a command on the remote host and gzips its stdout. This is the variant for anything that can
print its own backup: a vendor CLI, `sqlite3 .dump`, `tar` to stdout — and above all **network
devices**, which have nowhere to run a backup agent and whose entire state is a text config the CLI
will happily print.

Same authentication and `SSH_*` variables as `sshfile`, plus:

| Variable | Required |
| --- | --- |
| `SSH_COMMAND` | **yes** |

> [!IMPORTANT]
> `SSH_COMMAND` is interpreted by whatever the remote side runs — a shell on a Linux host, but the
> **device CLI** on a router or switch. Pipes, redirections and `;` chaining do not work against
> RouterOS or IOS. Pass one CLI command and post-process after download.

Whatever the command writes to **stdout** is the backup, verbatim — banners, prompts and progress
chatter included. Keep those on stderr.

#### MikroTik / RouterOS

`/export` prints the full configuration as replayable CLI commands. Since RouterOS 6.45 it masks
passwords, PSKs and keys unless you add `show-sensitive`, so a backup meant for a real restore wants
the sensitive form — which is exactly why `BACKUP_PASSWORD` is not optional here.

```shell
docker run --rm \
  -e SSH_HOST=10.10.0.1 \
  -e SSH_PORT=22 \
  -e SSH_USER=backup \
  -e SSH_PASSWORD=... \
  -e SSH_COMMAND="/export show-sensitive" \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=network/mikrotik/core-rtr-01 \
  -e BACKUP_SCHEDULE="0 4 * * *" \
  -e BACKUP_RETENTION_DAYS=90 \
  -e BACKUP_PASSWORD=a-long-passphrase \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:sshcommand
```

Add `terse` (`/export show-sensitive terse`) for one-command-per-line output, which diffs far better
between runs. Use `/export verbose` if you want default values included too.

A least-privilege account on the device — `read` to see the config, `sensitive` to unmask secrets,
`ssh` to log in, and nothing else:

```routeros
/user group add name=backup policy=ssh,read,sensitive
/user add name=backup group=backup password="..." address=10.20.0.0/24
```

> [!NOTE]
> `/export` is a **text** config, not RouterOS's binary `/system backup save` file. The binary form
> is written to the device's own filesystem rather than stdout, so it cannot travel through this
> variant — fetch it over SFTP/FTP separately if you need it. The text export is the more portable
> artifact anyway: it is human-readable, diffable, and replayable on different hardware.

#### Cisco IOS / IOS-XE

```shell
docker run --rm \
  -v /etc/backup/ssh_config:/root/.ssh/config:ro \
  -e SSH_HOST=10.10.0.2 \
  -e SSH_PORT=22 \
  -e SSH_USER=backup \
  -e SSH_PASSWORD=... \
  -e SSH_COMMAND="show running-config" \
  -e S3_BUCKET=my-backups \
  -e S3_PREFIX=network/cisco/core-sw-01 \
  -e BACKUP_SCHEDULE="20 4 * * *" \
  -e BACKUP_RETENTION_DAYS=90 \
  -e BACKUP_PASSWORD=a-long-passphrase \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  ghcr.io/parmincloud/containers/backups:sshcommand
```

`show running-config` needs privilege 15. `length 0` on the vty lines keeps IOS from paginating the
output with `--More--`:

```cisco
username backup privilege 15 secret <strong-password>
!
ip access-list standard MGMT-SSH
 permit 10.20.0.0 0.0.0.255
!
line vty 0 15
 transport input ssh
 access-class MGMT-SSH in
 length 0
 exec-timeout 5 0
```

Use `show running-config all` to capture defaults as well, or `show startup-config` to archive what
the device will actually boot with — the two differing is itself worth knowing about.

#### Legacy SSH algorithms

Older IOS images negotiate key exchange, host key and cipher algorithms that current OpenSSH
releases refuse outright, so the connection fails before authentication with something like
`Unable to negotiate ... no matching key exchange method found`. The images ship a modern OpenSSH, so
re-enable what your device needs through a client config mounted at `/root/.ssh/config`:

```sshconfig
Host *
    KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    Ciphers +aes128-cbc,aes256-cbc
    MACs +hmac-sha1
```

The `+` form appends to the defaults, so modern devices keep negotiating modern algorithms. Only add
the lines you actually need — each one weakens the connection for every host matched by the pattern,
so prefer a `Host 10.10.0.2` block over `Host *` when just a few devices are the problem.

> [!NOTE]
> OpenSSH requires `~/.ssh/config` to be owned by root or the invoking user and not writable by
> others. These images run as root, so the file on the host must be `chown 0:0` and `chmod 600`
> (or `644`) — otherwise SSH exits with `Bad owner or permissions`.

If you use key authentication instead of a password, note that many IOS versions only accept RSA
keys in `ip ssh pubkey-chain`, so generate an RSA key rather than ed25519 for those devices.

#### Restoring and reviewing

The object is a plain gzipped text file:

```shell
gunzip -c 2026-08-23T04:00:00.gz > core-rtr-01.rsc     # add .gpg handling if encrypted
```

Device configs come back with CR-LF line endings from some firmware. Normalise them locally if your
tooling cares — the container stores the stream verbatim:

```shell
gunzip -c 2026-08-23T04:00:00.gz | tr -d '\r' > core-rtr-01.rsc
```

Restore on RouterOS by uploading the `.rsc` and replaying it with `/import file-name=core-rtr-01.rsc`
(on a factory-reset device, or after `/system reset-configuration no-defaults=yes skip-backup=yes`).
On IOS, paste the config into the terminal in configuration mode, or copy it to `startup-config`.

Because each run is one host, a fleet means one container (or one `CronJob`) per device with its own
`S3_PREFIX` — which is what makes the per-device prefix in the examples above worth keeping. Stagger
the schedules rather than hitting every device at `0 4 * * *`; control planes on small routers are
easily saturated by a config dump.

> [!TIP]
> Diffing consecutive objects under a device's prefix turns this into a lightweight configuration
> audit trail — you get to see exactly what changed on the network last night, and when someone
> made a change they did not write down.

## Scheduling

### Built-in cron

Set `BACKUP_SCHEDULE` to a 5-field cron expression. The container installs a system crontab and
stays running, which suits Docker, Compose, and a long-lived Kubernetes `Deployment`:

```shell
-e BACKUP_SCHEDULE="0 2 * * *"     # every day at 02:00 container-local time
```

The container's timezone is UTC unless you set `TZ` and mount zone data. An in-flight backup is
protected by a lock file, so a slow run is never overlapped by the next tick.

### External schedulers — omit `BACKUP_SCHEDULE`

When something else already owns scheduling — a Kubernetes `CronJob`, Nomad periodic batch, a
systemd timer, or the host's own crontab — **leave `BACKUP_SCHEDULE` unset or empty**. The container
then performs exactly one backup, exits `0` on success (non-zero on failure), and never starts
`cron`. That is what lets the surrounding `Job` complete and report status correctly.

#### Kubernetes `CronJob`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: pg-backup
type: Opaque
stringData:
  PGPASSWORD: secret
  BACKUP_PASSWORD: a-long-passphrase
  AWS_ACCESS_KEY_ID: ...
  AWS_SECRET_ACCESS_KEY: ...
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pg-backup
spec:
  # Scheduling lives here — BACKUP_SCHEDULE is intentionally NOT set on the container.
  schedule: "0 2 * * *"
  timeZone: Asia/Tehran            # Kubernetes >= 1.27
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 3600
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: ghcr.io/parmincloud/containers/backups:pg18-dump
              env:
                - name: PGHOST
                  value: postgres.default.svc.cluster.local
                - name: PGPORT
                  value: "5432"
                - name: PGUSER
                  value: postgres
                - name: S3_BUCKET
                  value: my-backups
                - name: S3_PREFIX
                  value: prod/pg-dump
                - name: BACKUP_RETENTION_DAYS
                  value: "14"
                - name: AWS_DEFAULT_REGION
                  value: us-east-1
              envFrom:
                - secretRef:
                    name: pg-backup
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  memory: 1Gi
```

Notes for the Kubernetes case:

* `concurrencyPolicy: Forbid` matters. The in-container lock file only guards runs inside a single
  container, so it cannot stop the control plane from starting a second overlapping `Job`.
* Give the pod enough ephemeral storage for the archive — it is written to `/tmp` before upload. Set
  `resources.requests.ephemeral-storage`, or mount an `emptyDir` at `/tmp` if your nodes are tight
  on disk.
* Use `restartPolicy: OnFailure` with a small `backoffLimit` so a transient network error retries
  without hammering the database.
* For a `file-backup` job, mount the volume at `/data`. With a `ReadWriteOnce` PVC the backup pod
  must land on the same node as the writer, so prefer `ReadOnlyMany`/`ReadWriteMany` where your
  storage class supports it.
* `kubectl create job --from=cronjob/pg-backup pg-backup-manual` triggers an out-of-band run using
  the same spec.

`file-backup` under a `CronJob`, for contrast:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: uploads-backup
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: ghcr.io/parmincloud/containers/backups:file-backup
              env:
                - name: DATA_DIR
                  value: /data
                - name: S3_BUCKET
                  value: my-backups
                - name: S3_PREFIX
                  value: prod/uploads
                - name: BACKUP_RETENTION_DAYS
                  value: "30"
                - name: AWS_DEFAULT_REGION
                  value: us-east-1
              envFrom:
                - secretRef:
                    name: uploads-backup
              volumeMounts:
                - name: uploads
                  mountPath: /data
                  readOnly: true
                - name: tmp
                  mountPath: /tmp
          volumes:
            - name: uploads
              persistentVolumeClaim:
                claimName: uploads
                readOnly: true
            - name: tmp
              emptyDir: {}
```

#### Nomad periodic batch job

```hcl
job "mysql-backup" {
  type = "batch"

  periodic {
    cron             = "30 2 * * *"
    prohibit_overlap = true
  }

  group "backup" {
    task "dump" {
      driver = "docker"

      config {
        image = "ghcr.io/parmincloud/containers/backups:mysqldump"
      }

      # No BACKUP_SCHEDULE — Nomad's periodic stanza drives the schedule.
      env {
        MYSQL_HOST = "mysql.service.consul"
        MYSQL_PORT = "3306"
        MYSQL_USER = "root"
        S3_BUCKET  = "my-backups"
        S3_PREFIX  = "prod/mysql"
        BACKUP_RETENTION_DAYS = "14"
        AWS_DEFAULT_REGION    = "us-east-1"
      }
    }
  }
}
```

#### systemd timer or host crontab

```shell
# /etc/cron.d/pg-backup — the host's cron schedules it, the container just runs once.
0 2 * * * root docker run --rm --env-file /etc/pg-backup.env ghcr.io/parmincloud/containers/backups:pg18-dump
```

## Encryption

Set `BACKUP_PASSWORD` and the archive is encrypted with `gpg --symmetric` before upload, adding a
`.gpg` suffix (`backup.tar.gz.gpg`, `dump.sql.gz.gpg`). Decrypt with the same passphrase:

```shell
gpg --decrypt --batch --passphrase "$BACKUP_PASSWORD" \
  2026-08-23T02:00:00.sql.gz.gpg > 2026-08-23T02:00:00.sql.gz
```

Store the passphrase somewhere separate from the bucket — without it the backups are unrecoverable.

## Retention

`BACKUP_RETENTION_DAYS=N` deletes objects under `S3_PREFIX` whose `LastModified` is at or before
midnight of `today - N days`, after each successful upload. Re-read the warning in
[Common environment variables](#common-environment-variables): the prune is scoped by prefix only,
so a job with no prefix will delete unrelated objects in the bucket. Object-lock or bucket lifecycle
rules on the storage side are a good second line of defence.

## Notes

* Images run as `root` — `cron` and the SSH/database clients expect it.
* Only `linux/amd64` images are published.
* Unknown host keys are accepted on first use: the SSH variants populate `known_hosts` with
  `ssh-keyscan` on every run. On an untrusted network, bake a pinned `known_hosts` into a derived
  image instead.
* In the SSH variants the auth-mode branch (`[ "$SSH_AUTH" = *"key"* ]`) compares against a literal
  string rather than globbing, so the `sshpass` branch is always taken. Key-based auth still works —
  the key is loaded into `ssh-agent` and `sshpass` only supplies a password when SSH actually
  prompts for one.
* `pg_dumpall` and `mysqldump`/`mariadb-dump` stream through `gzip -9`; on large datasets the run is
  CPU-bound on compression.
* `file-backup` does not skip an empty `DATA_DIR` — its "nothing to backup" guard never triggers, so
  an empty directory still produces and uploads an empty archive.
