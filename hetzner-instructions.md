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
