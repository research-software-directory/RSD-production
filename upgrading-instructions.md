This document contains instructions for upgrading an existing RSD installation.

## Pick a version

When a [new version of the RSD is released](https://github.com/research-software-directory/RSD-as-a-service/releases), you might want to upgrade your instance. We recommend you pick the newest version, as this contains the latest features and bug and security fixes. However, if you are far behind, you might want to upgrade in multiple smaller steps.

## Download database migration scripts

Some RSD upgrades require a database migration. The RSD team provides these [in the migration-scripts directory](./database-migration/migration-scripts). Make sure to download and concatenate all scripts from the version you're running up to the version you're going to upgrade to. Alternatively, upgrade the RSD in multiple steps.

Some upgrades don't require a migration script (for which we provide a near-empty file), while some require one or more extra manual steps. Read the instructions of the releases extra carefully in this case and make sure you're prepared.

## Set an announcement on the RSD

As RSD admin, activate a global announcement that you are going to upgrade the RSD and that some downtime might be expected.

## Download the new version

Download the new zip file and unzip it (see the [installation instructions](./installation-instructions.md)) and make sure **not to overwrite your existing `nginx.conf` file**, as it contains the config for your particular RSD. The release notes will contain instructions on manual steps to take to update your `nginx.conf` file (which usually is not needed).

## Make a backup

**If the new version contains a major Postgres upgrade, read the instructions under "Extra steps when upgrading a major Postgres version" first.**

Be sure to make a backup first before upgrading the RSD

```bash
./make-backup.sh
```

## Upgrade the RSD

Since you've unzipped a new `docker-compose.yml` in a previous step, you just need to run the following to upgrade the RSD

```bash
docker compose up --detach
```

## Run the migration script

As described above, you should have a migration script ready for some of the upgrades. We assume your script is called `migration.sql`.

Copy the file to the database container:
```bash
docker cp migration.sql database:migration.sql
```

Now we can execute the statements in this file. The `--single-transaction` flag is **very** important, you might end up in a corrupted state otherwise:

```bash
docker compose exec database psql --dbname=rsd-db --username=rsd --single-transaction --file=migration.sql
```

We need to [reload the schema cache](https://postgrest.org/en/v10.0/schema_cache.html#schema-reloading) of PostgREST:

```bash
docker compose kill -s SIGUSR1 backend
```

## Extra steps when upgrading a major Postgres version

The official instructions can be found [here](https://www.postgresql.org/docs/current/upgrading.html), but the following steps work for us. This assumes you have already upgraded to the new RSD version and have a backup in place from just before upgrading.

1. Stop all containers that can write to the database:

```bash
docker compose stop nginx scrapers background-services
```

2. Now make the backup as described above and proceed with the upgrade
3. Remove the database volume, check with `docker volume ls` what its name is and remove it with `docker volume rm`
4. Rename (or copy) the backup with a timestamp in its name to `rsd-backup.tar` with `mv` or `cp`
5. Restore the backup, as described in the [installation instructions](./installation-instructions.md)
6. Start the stopped containers:

```bash
docker compose start nginx scrapers background-services
```
