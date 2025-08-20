## Initial setup

Create an SSH key, upload it to LastPass, then use that key to create the server on Hetzner. Make sure to restrict permissions on the key (make it read-only):

```bash
chmod 400 private-key
```

Then SSH into the server with

```bash
ssh -i private-key root@91.99.169.124
```

```bash
apt-get update && sudo apt-get install unzip
```

Follow the [Docker installation instructions here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) to install Docker. Also follow the [post install instructions](https://docs.docker.com/engine/install/linux-postinstall/) to be able to run Docker as regular user.

A non-root user `rsd` was created to run the Docker containers.

### Install the RSD
We first need to download the required files from the release we want to use:

```bash
curl --location --output release.zip https://github.com/research-software-directory/RSD-as-a-service/releases/download/v5.0.0/deployment.zip && unzip release.zip
```

See https://github.com/research-software-directory/RSD-as-a-service/releases for other releases.

Now create the env file and fill in or adapt the values:

```bash
cp .env.example .env && nano .env
```

Make sure to make a note of the passwords you set and store them somewhere safe. 

Enter the domain(s) you want NGINX to listen to, look for the line that says `server_name


localhost`:
```bash
nano nginx.conf
```

Now you are ready to launch the RSD:
```bash
docker compose up --detach
```
To obtain https certificates, make sure the domain name points to your vm and run
```bash
docker compose exec nginx bash -c 'certbot --nginx -d domain.example.com --agree-tos -m email@example.com'
```
Visit your domain, the RSD should now be running!

To obtain https certificates, make sure the domain name points to your vm and run

```bash
docker compose exec nginx bash -c 'certbot --nginx -d research-software-directory.org -d www.research-software-directory.org -d research.software -d research-software.nl -d www.research-software.nl --agree-tos -m email@example.com'
```

### Automatically renew https certificates

Run the following to check the certificates every day at 5 AM:

```bash
echo "0 5 * * * /usr/bin/bash -c 'docker compose exec --no-TTY nginx /usr/bin/certbot renew'" | crontab -
```

## Backups

For storing backups in AWS S3, we use the AWS CLI. Use the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) to install the AWS CLI and [autenticate yourself](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html) on the CLI.

Use the following script to make backups:

```bash
#!/bin/bash
rm *-rsd-backup.tar

docker compose exec --no-TTY database pg_dump --format=tar --file=rsd-backup.tar --username=rsd --dbname=rsd-db
docker cp database:rsd-backup.tar rsd-backup.tar

mv rsd-backup.tar $(date --utc -Iseconds)-rsd-backup.tar

file=$(ls *-rsd-backup.tar)

# AWS S3
# https://docs.aws.amazon.com/cli/latest/reference/s3/
aws s3 cp "$file" "s3://your-bucket"

# SURFdrive
# https://servicedesk.surf.nl/wiki/spaces/WIKI/pages/74225505/Activating+WebDAV
curl --user username:password --upload-file ${file} \
  "https://surfdrive.surf.nl/files/remote.php/nonshib-webdav/rsd-backups/"

# Hetzner storage box
# https://docs.hetzner.com/storage/storage-box/access/access-sftp-scp
scp -P 23 -i backup-maker.key ./${file} user@user.your-storagebox.de:
```

Make it execuable:

```bash
chmod +x make-backup.sh
```

And add it to the crontab:

```bash
(crontab -l ; echo "0 4 * * * /home/ubuntu/make-backup.sh") | crontab -
```

## Update the RSD

As admin, activate a global announcement that you are going the RSD and that some downtime might be expected.

When a [new version of the RSD is released](https://github.com/research-software-directory/RSD-as-a-service/releases), you might want to update your instance. Download the new zip file and unzip it (see the instructions above) and make sure to only replace the `nginx.conf` file if you need the update and made a backup of the old one. Make a backup first:

```bash
./make-backup.sh
```

Then run

```bash
docker compose up --detach
```
to update the containers. You then might have to update the database schema. See the [database-migration](https://github.com/research-software-directory/RSD-production/tree/main/database-migration) directory of this repo for instructions and check the [migration-scripts](https://github.com/research-software-directory/RSD-production/tree/main/database-migration/migration-scripts) directory in there for scripts that allow you to update the database between two consecutive versions.

If you set a global announcement, disactivate it.

## Restoring a backup

First place the backup file in the container:
```bash
docker cp rsd-backup.tar database:rsd-backup.tar
```

And to restore the backup, run 

```bash
docker compose exec database pg_restore --username=rsd --dbname=rsd-db --clean rsd-backup.tar
```

*Warning:* note that the `--clean` flag will first clear the database.
