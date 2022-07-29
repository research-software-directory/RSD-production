# RSD Database migration from v1.1.1 to v1.2.0

The version 1.2.0 introduces additional features that require database upgrade. The database volume from the previous version v1.1.x cannot be used without an upgrade.

The required changes in the database are:

- `meta_pages` table is added to the database, including RLS rules to allow only the rsd admins to modify the content
- filtering on keywords for software and project pages required changes `in the following functions`:
  - projects_by_organisation
  - related_projects_for_project
  - related_projects_for_software
  - software_list
  - software_search
  - projects_by_maintainer
  - project_search

## Migrate v1.1.1 database to v1.2.0

To migrate your 1.1.x database version we advice the following approach:

- create data dump / backup. Always create backup before you start.
- run this migration process on the local machine first to practice and confirm that all steps went well.

```bash
# create pg_dump file rsd-backup-v11.tar in the home folder of database container
docker-compose exec database pg_dump --format=tar --file=home/rsd-backup-v11.tar --username=rsd --dbname=rsd-db
# copy backup file from the container to a local folder
docker cp database:home/rsd-backup-v11.tar rsd-backup-v11.tar
```

- confirm the backup file is correct by restoring it on some other instance (location)
- run database migration script `20220729-database-migration.sql`. It should complete without errors. Please note that some parts of rsd app do not work properly at this stage, for example software page will not be loaded properly.

```bash
# copy migration file to home folder of database service
docker cp 20220729/20220729-database-migration.sql database:home/20220729-database-migration.sql
# run migration script using psql
docker-compose exec database psql -h localhost -d rsd-db -U rsd -f home/20220729-database-migration.sql
```

- If the migration script completed without any errors, next steps is to create backup of upgraded database

```bash
# create pg_dump file rsd-backup-v12.tar in the home folder of database container
docker-compose exec database pg_dump --format=tar --file=home/rsd-backup-v12.tar --username=rsd --dbname=rsd-db
# copy this file from the container to a local folder
docker cp database:home/rsd-backup-v12.tar rsd-backup-v12.tar
```

Confirm that new backup is working properly by recovering it on different instance and using RSD 1.2.0 images

## Start v1.2.0 version

If a new backup is working properly (see previous step) you can start new version in 2 different ways:

- using updated volume of docker database service
- starting new instance and restoring the backup you created at previous step (rsd-backup-v12.tar)

In 1.2.0 version we introduced 3 new env. variables:

- COMPOSE_PROJECT_NAME: root name of rsd services used by docker-compose. It results in the different volume and network names!
- MATOMO_URL: definitions for motomo monitoring tool
- MATOMO_ID: definitions for motomo monitoring tool

If you want to use COMPOSE_PROJECT_NAME, which will change "root" name of rsd volume and network you will need to migrate your data into new volume by restoring the backup you previously created (rsd-backup-v12.tar).

If you don't want to use COMPOSE_PROJECT_NAME env variable (comment it out) or you define same name as previously used by docker, you can simply start RSD 1.2.0 by using the docker-compose.yml file provided in the 1.2.0 release.

- download new [deployment.zip](https://github.com/research-software-directory/RSD-as-a-service/releases/download/v1.2.0/deployment.zip). Note that docker-compose.yml files have the same names.
- bring the current version down but keep the data volume so we can reuse it `docker-compose down`.
- rename old docker-compose.yml or move to some other location (just in case)
- extract docker-compose.yml file from downloaded deployment.zip.
- start rsd using new docker-compose.yml file `docker-compose up -d`
- confirm that data is properly loaded by visiting http://localhost/software. You should also see filtering option and would be able to use it.

This approach is tested localy on machine with Linux Mint 20.
