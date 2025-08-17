
---

# 🚀 Deployment on the Server on the vm

## 0. Connect via ssh

```bash
ssh -i '/path/to/keyfile' root@<server_ip>
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
```
Log out and log back in for this change to take effect

### 1. Install k3s.io

Download and run the k3s installation script

```bash
curl -sfL https://get.k3s.io | sh -
```
The installer automatically sets up a service to run k3s on boot.

### 2. Configure kubectl Access

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

### 3. Set up SSH Key-Based Authentication
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
ssh-copy-id -i ~/.ssh/server-name-github.pub root@<server_ip>
```
from Windows
```bash
type '/path/to/server-name-github.pub' | ssh -i '/path/to/keyfile' root@188.245.90.55 "cat >> .ssh/authorized_keys"
```
---

## 2. The Initial Manual Deployment 🎬

### 0. Create the secrets.yaml

Copy secrets-blueprint.yaml into a new file secrets.yaml.
Then modify the variables.

### 1. Copy the deplyment files

You only need to do this once to get the cluster state set up.

Copy your files to the server. From your local machine, use scp to transfer your configuration files to the server.

From the repo /kube folder, run

```bash
scp -i '/path/to/keyfile' secrets.yaml mongodb-deploy.yaml rest-server-deploy.yaml deploy.sh root@<_server_ip>:~/
```
### 2. Run the deployment script. 

SSH into the server and run deploy.sh.

```bash
# Once on the server
chmod +x deploy.sh
./deploy.sh
```
After this script finishes, the entire application stack should be running on the server. You can verify this with 
```bash
kubectl get all
```

---
## 3. Configure the CI/CD Pipeline with GitHub Actions 🚀

### 1. Store Secrets in GitHub

The GitHub Actions workflow needs credentials to log into Docker Hub and your server. Store these securely in your GitHub repository's secrets.

Go to your repo on GitHub -> Settings -> Secrets and variables -> Actions.\
Click New repository secret for each of the following:

* DOCKERHUB_USERNAME: The Docker Hub username.

* DOCKERHUB_TOKEN: An access token from Docker Hub. (In Docker Hub: Account Settings -> Personal Access Token -> Generate new token, with Read and Write permissions).

 * SSH_PRIVATE_KEY: The contents of your private key file (~/.ssh/github_actions). Open the file and copy everything.

* SSH_HOST: The server's IP address (e.g., 192.168.1.100).

* SSH_USER: The username you use to log into your Debian server (e.g., root).

* SUBMODULE_TOKEN: The token with repo scope to allow submodule fetching

### 2. Create the GitHub Actions Workflow File
In the project's root directory, create the folder structure and file: .github/workflows/deploy.yml.

---





## 🔒 Firewall Configuration

### 1. Enable UFW

```bash
sudo ufw enable
```

### 2. Allow Essential Services

```bash
sudo ufw allow ssh
sudo ufw allow 8080/tcp
```

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