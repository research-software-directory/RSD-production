The SSH key can be found in LastPass. The username is ec2-user. SSH into the VM with

Make the key read only:

```bash
chmod 400 kin-rpd-production-key.pem
```

Then SSH into the server with

```bash
ssh -i kin-rpd-production-key.pem ec2-user@18.199.158.232
```
