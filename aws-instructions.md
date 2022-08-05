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
curl --location --output release.zip https://github.com/research-software-directory/RSD-as-a-service/releases/download/v1.1.1/deployment.zip && unzip release.zip
```
See https://github.com/research-software-directory/RSD-as-a-service/releases for other releases.

Now create the env file and fill in or adapt the values:
```bash
cp .env.example .env && nano .env
```
Make sure to make a note of the passwords you set and store them somewhere safe. 

Enter the domain(s) you want NGINX to listen to, look for the line that says `server_name  localhost`:
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
echo "0 5 * * * /usr/bin/bash -c  'docker-compose exec -T nginx /usr/bin/certbot renew'" | crontab -
```

### Automatically create backups to S3
Create a backup script (fill in the values first). This script was adapted from https://glacius.tmont.com/articles/uploading-to-s3-in-bash:
```bash
echo '
#!/bin/bash
rm *-rsd-backup.tar

docker-compose exec -T database pg_dump --format=tar --file=rsd-backup.tar --username=rsd --dbname=rsd-db
docker cp database:rsd-backup.tar rsd-backup.tar

mv rsd-backup.tar $(date --utc -Iseconds)-rsd-backup.tar

file=$(ls *-rsd-backup.tar)
bucket_folder=your/s3/subfolders
bucket=your-bucket
resource="/${bucket}/${bucket_folder}/${file}"
contentType="application/x-compressed-tar"
dateValue=`date -R`
stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
s3Key=xxxxxxxxxxxxxxxxxxxx
s3Secret=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
curl -X PUT -T "${file}" \
  -H "Host: ${bucket}.s3.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: ${contentType}" \
  -H "Authorization: AWS ${s3Key}:${signature}" \
  https://${bucket}.s3.amazonaws.com/${bucket_folder}/${file}
' > make-backup.sh
```
See e.g. https://supsystic.com/documentation/id-secret-access-key-amazon-s3/ on how to obtain a key and secret.

Make it execuable:
```bash
chmod +x make-backup.sh
```
And add it to the crontab:
```bash
(crontab -l ; echo "0 4 * * * /home/ubuntu/make-backup.sh") | crontab -
```

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
