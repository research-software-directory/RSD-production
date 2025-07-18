## Initial setup

The SSH key can be found in LastPass.

Make the key read only:

```bash
chmod 400 kin-rpd-production-key.pem
```

Then SSH into the server with

```bash
ssh -i kin-rpd-production-key.pem ubuntu@3.72.246.175
```

Install `unzip`:

```bash
sudo apt-get update && sudo apt-get install unzip
```

Follow the [Docker installation instructions here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) to install Docker. Also follow the [post install instructions](https://docs.docker.com/engine/install/linux-postinstall/) to be able to run Docker as regular user.

## Install the RPD

Download the RPD:

```bash
curl --location --output release.zip https://github.com/research-software-directory/KIN-RPD/releases/download/v1.1.0/deployment.zip && unzip release.zip
```

Now create the env file and fill in or adapt the values:

```bash
cp .env.example .env && nano .env
```

Make sure to make a note of the passwords you set and store them somewhere safe. 

Edit the `nginx.conf`. Remove the block that looks like:

```
server {
        listen       80;
        server_name  www.localhost;
        return 301 $scheme://localhost$request_uri;
}
```

Furthermore, change the line containing `server_name  localhost;` and replace `localhost` with your domain name, which in our case is `vedaresearch.nl`.

Now you are ready to launch the RSD:

```bash
docker compose up --detach
```

To obtain https certificates, make sure the domain name points to your vm and run

```bash
docker compose exec nginx bash -c 'certbot --nginx -d vedaresearch.nl --agree-tos -m email@example.com'
```

Visit your domain, the RSD should now be running!

To allow a secondary domain, add the following block, editing the domain if necessary:

```
server {
        server_name  vedanet.nl www.vedanet.nl www.vedaresearch.nl;
        return 301 https://vedaresearch.nl$request_uri;
}
```
And then run, as before:

```bash
docker compose exec nginx bash -c 'certbot --nginx -d vedanet.nl -d www.vedanet.nl -d www.vedaresearch.nl --agree-tos -m email@example.com'
```

### Automatically renew https certificates

Run the following to check the certificates every day at 5 AM:

```bash
echo "0 5 * * * /usr/bin/bash -c 'docker compose exec --no-TTY nginx /usr/bin/certbot renew'" | crontab -
```

### Automatically create backups to S3

Create an IAM user that can create new objects in one S3 bucket. Specifically, the user must (only) have `write` permission `PutObject` on (only) the bucket used from backups, ideally restricting the allowed IP addresses to only the VM one. This can all be done from the AWS console.

Use the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) to install the AWS CLI and [autenticate yourself](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html) on the CLI.

Create a file called `make-backup.sh` with the following content:

```bash
#!/bin/bash
rm *-rsd-backup.tar

docker compose exec --no-tty database pg_dump --format=tar --file=rsd-backup.tar --username=rsd --dbname=kin-rpd-db
docker cp database:rsd-backup.tar rsd-backup.tar

mv rsd-backup.tar $(date --utc -Iseconds)-rsd-backup.tar

file=$(ls *-rsd-backup.tar)

/usr/local/bin/aws s3 cp "$file" "s3://your-bucket-name"
```
Make it execuable:

```bash
chmod +x make-backup.sh
```

And add it to the crontab:

```bash
(crontab -l ; echo "0 4 * * * /home/ubuntu/make-backup.sh") | crontab -
```
