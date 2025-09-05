# Database migration with migra
When we update the database schema, we update the existing initialisation files in the database directory, instead of writing diffs in new files. This has the advantage of being able to see all the info of a specific table in one place, namely the file where the corresponding `CREATE TABLE` statement is. 

However, a consequence is that when we do this, the database schema of the running database will be behind of what's in the initialisation sql files. We need some way to diff the running database with those initialisation files.

We use the migra tool to compare these and to generate a sql migration script. We do this by creating a new empty database with the latest structure, so that migra can compare the differences and output those in a migration file. This migration script contains the schema operation that need to be performed in order to make the structure of the current database align with the new version.

migra is open source and the [repo is here](https://github.com/djrobstep/migra).
    The [documentation website is here](https://databaseci.com/docs/migra/quickstart).

## Steps to generate and execute migration script
Copy the `database-migration.yml` file and the `migra` and `database` directories to the directory where you host the RSD (i.e. the directory where the `.env` and `docker-compose.yml` files are):
```bash
curl --location --output migration.zip https://github.com/research-software-directory/RSD-production/archive/refs/heads/main.zip 
unzip -j migration.zip RSD-production-main/database-migration/database-migration.yml
unzip -j migration.zip RSD-production-main/database-migration/database/* -d database
unzip -j migration.zip RSD-production-main/database-migration/migra/* -d migra
```

Copy the initialisation files from the running database container to the database directory:
```bash
docker cp database:/docker-entrypoint-initdb.d/. database/.
```
Now build the images:
```bash
docker compose --file database-migration.yml build --parallel
```
Then create and run the containers:
```bash
docker compose --file database-migration.yml up
```
Wait until migra has run (it waits for 10 seconds before operating). When it exits with exit code `0`, no differences where found, whereas when it exits with exit code `2`, differences *were* found. In both cases, stop the containers with `Ctrl+C`.

In the case of differences, copy the file from the container to the local file system:
```bash
docker cp migra:migration.sql migration.sql
```
**Important:** inspect the file carefully. It might contain dangerous statements like `DROP` statements. It is known that it does not handle `WITH CHECK` statements within `CREATE POLICY` statements correctly. You need to manually add parantheses after the `WITH CHECK` statement:
```bash
nano migration.sql
```
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
You can now safely delete the migration containers and volumes. You need to do this in order for migra to detect new changes the next time you repeat this procedure:
```bash
docker compose --file database-migration.yml down --volumes
```
Finally, cleanup the database files for the next time:
```bash
rm database/*.sql database/*.sh
```
