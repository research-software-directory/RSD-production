This document contains instructions for generating a migration script between two RSD versions.

## Motivation

When we update the database schema, we update the existing initialisation files in the database directory, instead of writing diffs in new files. This has the advantage of being able to see all the info of a specific table in one place, namely the file where the corresponding `CREATE TABLE` statement is.

However, a consequence is that when we do this, the database schema of the running database will be behind of what's in the initialisation SQL files. We need some way to diff the running database with those initialisation files.

We use the migra tool to compare these and to generate a SQL migration script. We do this by creating a new empty database with the latest structure, so that migra can compare the differences and output those in a migration file. This migration script contains the schema operation that need to be performed in order to make the structure of the current database align with the new version.

migra is open source and the [repo is here](https://github.com/djrobstep/migra).
The [documentation website is here](https://databaseci.com/docs/migra/quickstart).

## High level overview

We use migra to generate a "diff" between a running RSD instance with an outdated schema and an ad hoc database instance that runs on the newest database schema. This could be done at two places:

1. Your production RSD at the vm and an ad hoc instance running there.
2. An RSD instance running on your own machine mirroring the production instance version (no data needed) you want to upgrade and an ad hoc instance on your machine.

We recommend the second option, as you are not under pressure to upgrade your production instance quickly. The first option can be used ocasionally to check if your production instance is _actually_ up to date.

When doing the first option "live", you first need to upgrade your RSD instance, as the new database container will contain the necessary SQL files to create the ad hoc database instance. This means you will have an upgraded RSD instance running which has not yet migrated its database schema, which is not ideal, especially if migrating takes a long time.

## Generate the migration script

When doing this on your machine, make sure to have an RSD instance running of the same version as your production RSD.

The following part mentions files and directories which can be found in the [database-migration](./database-migration) directory. You can obtain these files by downloading them manually, by cloning this repository or by running the following commands (**preferred**). When doing this in production, the easiest is to to this in the same directory as in which the RSD is contained (i.e. the directory containing the `docker-compose.yml` of the RSD).

```bash
curl --location --output migration.zip https://github.com/research-software-directory/RSD-production/archive/refs/heads/main.zip 
unzip -j migration.zip RSD-production-main/database-migration/database-migration.yml
unzip -j migration.zip RSD-production-main/database-migration/database/* -d database
unzip -j migration.zip RSD-production-main/database-migration/migra/* -d migra
```

To create the ad hoc RSD database instance, we need to have the latest SQL initialisation files in the `database` directory created above. If you do this on your own machine, you should have these in your `RSD-as-a-service` project. If doing this on a production machine, you can obtain these by extracting them from the already upgraded (but not yet migrated) RSD database container with the following command:

```bash
docker compose cp database:/docker-entrypoint-initdb.d/. database/.
```

Now build the migra and ad hoc database images:

```bash
docker compose --file database-migration.yml build --parallel
```

Then create and run the containers:

```bash
docker compose --file database-migration.yml up
```

Wait until migra has run (it waits for 10 seconds before operating). When it exits with exit code `0`, no differences where found, whereas when it exits with exit code `2`, differences *were* found. In both cases, stop the containers with `Ctrl+C`.

In the case of differences, copy the file from the migra container to the local file system:

```bash
docker cp migra:migration.sql migration.sql
```

**Important:** inspect the file carefully. It might contain dangerous statements like `DROP` statements. It is known that it does not handle `WITH CHECK` statements within `CREATE POLICY` statements correctly. You need to manually add parentheses after the `WITH CHECK` statement. This is also the part where you have to check if additional, possibly manual, steps are needed.

```bash
nano migration.sql
```

Congratulations, you have created a migration script. We will first do some clean-up.

Delete the migration containers and volumes. You need to do this in order for migra to detect new changes the next time you repeat this procedure:

```bash
docker compose --file database-migration.yml down --volumes
```

Finally, clean up the database files for the next time:
```bash
rm database/*.sql database/*.sh
```

You can continue with the migration by following the instruction in [the upgrading instructions](upgrading-instructions.md) (under "Run the migration script").
