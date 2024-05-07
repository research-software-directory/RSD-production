### Setup docker
We first need to install docker, docker-compose and unzip:
```bash
sudo apt-get update && sudo apt-get install docker docker-compose unzip
```
According to https://docs.docker.com/engine/install/linux-postinstall/ we need to add the user to the docker group.
You might need to create the group first:
```bash
sudo groupadd docker
```
Then add yourself to the group
```bash
sudo usermod --append --groups docker $USER && newgrp docker
```
We then need to enable docker on startup:
```bash
sudo systemctl enable docker.service && sudo systemctl enable containerd.service
```

### Install the RSD
We first need to download the required files from the release we want to use:
```bash
curl --location --output release.zip https://github.com/research-software-directory/RSD-as-a-service/releases/download/v2.14.0/deployment.zip && unzip release.zip
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
docker-compose up --detach
```
To obtain https certificates, make sure the domain name points to your vm and run
```bash
docker-compose exec nginx bash -c 'certbot --nginx -d domain.example.com --agree-tos -m email@example.com'
```
Visit your domain, the RSD should now be running!

### Automatically renew https certificates
Run the following to check the certificates every day at 5 AM:
```bash
echo "0 5 * * * /usr/bin/bash -c 'docker-compose exec -T nginx /usr/bin/certbot renew'" | crontab -
```

### Automatically create backups to S3 and SURFdrive

We store our backups on AWS S3 and SURFdrive. We use the AWS CLI to easily upload backup files from our VM to their servers. The installation instructions for the AWS CLI can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

We recommend to create a dedicated IAM user that only has the `PutObject` permission on the S3 Bucket of your choice. After you've done this, create an [access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) for this user and configure the CLI with `aws configure` and `sudo aws configure`. The first variant is for when you manually want to run the backup script, and the latter is for the cron job.

We use the following bash script (named `make-backup.sh`) to create and upload the backups:

```bash
#!/bin/bash
rm *-rsd-backup.tar

docker-compose exec -T database pg_dump --format=tar --file=rsd-backup.tar --username=rsd --dbname=rsd-db
docker cp database:rsd-backup.tar rsd-backup.tar

mv rsd-backup.tar $(date --utc -Iseconds)-rsd-backup.tar

file=$(ls *-rsd-backup.tar)

aws s3 cp "$file" "s3://your-bucket"

curl --user username:password --upload-file ${file} \
  "https://surfdrive.surf.nl/files/remote.php/nonshib-webdav/rsd-backups/"
```

Make it execuable:

```bash
chmod +x make-backup.sh
```

And add it to the crontab:

```bash
(crontab -l ; echo "0 4 * * * /home/ubuntu/make-backup.sh") | crontab -
```

### Update the RSD
When a [new version of the RSD is released](https://github.com/research-software-directory/RSD-as-a-service/releases), you might want to update your instance. Download the new zip file and unzip it (see the instructions above) and make sure to only replace the `nginx.conf` file if you need the update and made a backup of the old one . Make the backup first:
```bash
./make-backup.sh
```

As admin, activate a global announcement that you are updating the RSD.

Then run
```bash
docker-compose up --detach
```
to update the containers. You then might have to update the database schema. See the [database-migration](https://github.com/research-software-directory/RSD-production/tree/main/database-migration) directory of this repo for instructions and check the [migration-scripts](https://github.com/research-software-directory/RSD-production/tree/main/database-migration/migration-scripts) directory in there for scripts that allow you to update the database between two consecutive versions.

If you set a global announcement, disactivate it.

### Restoring a backup
First place the backup file in the container:
```bash
docker cp rsd-backup.tar database:rsd-backup.tar
```
And to restore the backup, run 
```bash
docker-compose exec database pg_restore --username=rsd --dbname=rsd-db --clean rsd-backup.tar
```
*Warning:* note that the `--clean` flag will first clear the database.
