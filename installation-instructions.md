This document contains instructions for installing a new RSD on a VM. It assumes that you have root access or that you have the necessary permissions to install any missing software and to run Docker.

## Connecting to the VM

Create a virtual machine (VM). Make note of its public IP address and change/create DNS settings at your DNS provider to point any desired domain names to this VM.

Create an SSH key to connect to the VM. Make sure the private key is read-only:

```bash
chmod 400 private-key
```

Then connect to the VM. Check the instructions of your provider to see if a different user than `root` is used.

```bash
ssh -i private-key root@ip-address
```

## Install dependencies

Assuming your VM uses `apt-get` to manage software packages, install `unzip`:

```bash
apt-get update && sudo apt-get install unzip
```

Follow the [Docker installation instructions here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) to install Docker.

For better security, we recommend to run Docker as a regular (non-root) user. Follow the [post install instructions](https://docs.docker.com/engine/install/linux-postinstall/) to be able to do this.

## Install the RSD

We first need to download the required files from the release we want to use:

```bash
curl --location --output release.zip https://github.com/research-software-directory/RSD-as-a-service/releases/download/v6.8.2/deployment.zip && unzip release.zip
```

See https://github.com/research-software-directory/RSD-as-a-service/releases for other releases (change the version number in the URL above when desired).

Now create the environment file and fill in and/or change the values:

```bash
cp .env.example .env && nano .env
```

Make sure to make a note of the passwords you set and store them somewhere safe. 

We will now configure NGINX to listen to the domain names you assigned to your instance.

```bash
nano nginx.conf
```

Replace every instance of `localhost` with your domain name. Optionally, add extra redirect blocks if you have multiple domains (e.g. `www` or something completely different). The `nginx.cong` that is shipped with the release has an example of redirecting `www.localhost` to `localhost`.

Now you are ready to launch the RSD (we can obtain the HTTPS certificates only when the RSD is running):
```bash
docker compose up --detach
```

To obtain the certificates, run the following command, where you replace the domain `example.com` _and_ the `email@example.com` email address:

```bash
docker compose exec nginx bash -c 'certbot --nginx -d example.com --agree-tos -m email@example.com
```

You can repeat the `-d example.com` if you have multiple domains.

For the NLeSC instance, we use:

```bash
docker compose exec nginx bash -c 'certbot --nginx -d research-software-directory.org -d www.research-software-directory.org -d research.software -d research-software.nl -d www.research-software.nl --agree-tos -m email@example.com'
```

Run the following to check the certificates every day at 5 AM:

```bash
echo "0 5 * * * /usr/bin/bash -c 'docker compose exec --no-TTY nginx /usr/bin/certbot renew'" | crontab -
```

## Backups

Make sure to automatically create and store backups at least every day. We use the following setup.

For storing backups in AWS S3, we use the AWS CLI. Follow the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) to install the AWS CLI and [authenticate yourself](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html) on the CLI both as root (since cron runs as root) and as regular user (to run the backup script below manually).

We then use the following script to make backups. You can adapt it as needed toy use your own storage solututions.

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

Make it executable:

```bash
chmod +x make-backup.sh
```

And add it to the crontab:

```bash
(crontab -l ; echo "0 4 * * * /home/rsd/make-backup.sh") | crontab -
```

Make sure to test the script by running it manually and be sure to check after the first automatic backup to see if the backups were indeed created and stored.

## Restoring a backup

First place the backup file in the database container (change the name of the file when needed):

```bash
docker cp rsd-backup.tar database:rsd-backup.tar
```

To restore the backup, run

```bash
docker compose exec database pg_restore --username=rsd --dbname=rsd-db --clean rsd-backup.tar
```

*Warning:* note that the `--clean` flag will first clear the database.
