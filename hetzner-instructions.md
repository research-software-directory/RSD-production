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

## Backups

For storing backups in AWS S3, we use the AWS CLI. Use the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) to install the AWS CLI and [autenticate yourself](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html) on the CLI.

Use the following script to make backups:

```bash
#!/bin/bash
rm *-rsd-backup.tar

docker-compose exec -T database pg_dump --format=tar --file=rsd-backup.tar --username=rsd --dbname=rsd-db
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
