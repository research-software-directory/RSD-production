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
curl --location --output release.zip https://github.com/research-software-directory/KIN-RPD/releases/download/v1.0.1/deployment.zip && unzip release.zip
```

Now create the env file and fill in or adapt the values:

```bash
cp .env.example .env && nano .env
```

Make sure to make a note of the passwords you set and store them somewhere safe. 
