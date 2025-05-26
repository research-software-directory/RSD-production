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
Follow the [Docker installation instructions here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) to install Docker. Also follow the [post install instructions](https://docs.docker.com/engine/install/linux-postinstall/) to be able to run Docker as regular user.

## Install the RPD

Download the RPD:

```bash
curl --location --output release.zip https://github.com/research-software-directory/KIN-RPD/releases/download/v1.0.1/deployment.zip && unzip release.zip
```
