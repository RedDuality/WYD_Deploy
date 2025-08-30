
---

# 🚀 Deployment on the Server on the vm

You will need a machine dedicated to this service.

## 0. Connect via ssh

```bash
ssh -i '/path/to/keyfile' <user>@<server_ip>
```

## 1. Prepare the VM

### 1. Update packages and install Docker & Compose:

```bash
# Update package lists
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io

# Enable and start the Docker service
sudo systemctl enable --now docker

# (Optional but recommended) Add your user to the docker group to run docker commands without sudo
sudo usermod -aG docker $USER
# Log out and log back in for this change to take effect
```

### 2. Install k3s.io

Download and run the k3s installation script

```bash
curl -sfL https://get.k3s.io | sh -
```
The installer automatically sets up a service to run k3s on boot.

### 3. Install helm

on linux(apt):

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

sudo apt-get install apt-transport-https --yes

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm
```

### 4. Configure kubectl Access

Create a .kube directory in your home folder
```bash
mkdir -p ~/.kube
```

Copy the k3s config file to your user's .kube directory and set permissions
```bash
sudo k3s kubectl config view --raw > ~/.kube/config
sudo chmod 600 ~/.kube/config
```

Test if you can connect to the cluster
```bash
kubectl get nodes
```

## 2. The Initial Manual Deployment 🎬

### 0. Prerequisites

You need a domain, a mail for let's encrypt and the static ip of your machine.

Initially, its ssl policy should be "Flexible" and not "Full".

### 1. Configure the environment variables

1. Inside deploy/rest-server/config
  - Copy secrets-blueprint.yaml into a new secrets.yaml file. Then modify the variables. 
  - (Optional) update the database name inside rest-server-config.yaml.
2. Inside deploy/ingress/config, configure config.env with your actual credentials.

### 2. Copy the deplyment files

You only need to do this once to get the cluster state set up.

Copy your files to the server. From your local machine, use scp to transfer your configuration files to the server.

From the repo /deploy folder, run

```bash
scp -i '/path/to/keyfile' -r ingress rest-server deploy.sh clear.sh root@<_server_ip>:~/deploy
```
### 3. Run the deployment script. 

SSH into the server and run deploy.sh.

```bash
# Once on the server
cd deploy
chmod +x deploy.sh
./deploy.sh
```

After this script finishes, the entire application stack should be running on the server. You can verify this with 
```bash
kubectl get all
kubectl get pods -A -w
```
### 4. Update the domain settings

Set SSL policy to "Full(Strict)".
If you want to setup a Firewall, allow only ports 22(SSH) and 443(HTTPS).

---
## 3. Configure the CI/CD Pipeline with GitHub Actions 🚀

### 1. Set up SSH Key-Based Authentication for GitHub Updates
1. On your local machine (or any machine you want to generate the key from), create a new SSH key pair:

```bash
ssh-keygen -t ed25519 -C "server-name-github-actions-key"
```
  When prompted, save it to a specific file, e.g., ~/.ssh/server-name-github.\
  Do NOT set a passphrase for this key, as the automated script can't enter one.

2. Copy the public key to your remote server:

Run this from the local machine.\

from linux
```bash
ssh-copy-id -i ~/.ssh/server-identifier-github-actions.pub <user>@<server_ip>
```
from Windows
```bash
type '/path/to/server-identifier-github-actions.pub' | ssh -i '/path/to/keyfile' <user>@<server_ip> "cat >> .ssh/authorized_keys"
```
---

### 2. Store Secrets in GitHub

The GitHub Actions workflow needs credentials to log into Docker Hub and your server. Store these securely in your GitHub repository's secrets.

Go to your repo on GitHub -> Settings -> Secrets and variables -> Actions.\
Click New repository secret for each of the following:

* DOCKERHUB_USERNAME: The Docker Hub username.

* DOCKERHUB_TOKEN: An access token from Docker Hub. (In Docker Hub: Account Settings -> Personal Access Token -> Generate new token, with Read and Write permissions).

* SSH_PRIVATE_KEY: The contents of your private key file created in the previous passage (~/.ssh/github_actions). Open the file and copy everything.

* SSH_HOST: The server's IP address (e.g., 192.168.1.100).

* SSH_USER: The username you use to log into your Debian server (e.g., root).

* SUBMODULE_TOKEN: The token with repo scope to allow submodule fetching

### 3. Create the GitHub Actions Workflow File
In the project's root directory, create the folder structure and file: .github/workflows/deploy.yml.

---





## 🔒 Firewall Configuration

Firewall should allow ports 22, 80, 443, 

### 3. 📡 MongoDB Access via SSH Tunnel

On your local machine:

```bash
ssh -i PathToSshPrivateKey -L 27017:127.0.0.1:27017 root@<VM_IP>
```

Then in Compass:

```text
mongodb://wyd_admin:Test_Password@localhost:27017/admin?authSource=admin
```

🔐 Replace `Test_Password` accordingly.

---