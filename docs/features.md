# 📡 Access MongoDB with Compass

Follow these steps to connect Compass to your **Kubernetes MongoDB service**.

---

### 1. Forward the Pod Port on the Server

On the **remote server**, run:

```bash
kubectl port-forward svc/mongodb-service 27017:27017
```

➡️ Keep this terminal open while you need the connection.

---

### 2. Create an SSH Tunnel

On your **local machine**, run:

```bash
ssh -i /path/to/ssh-private-key -L 27017:127.0.0.1:27017 <user>@<server_ip>
```

➡️ Keep this terminal open as well.

---

### 3. Connect via Compass

In Compass, connect using:

```text
mongodb://wyd_admin:Test_Password@localhost:27017/admin?authSource=admin
```

🔐 Replace `wyd_admin` and `Test_Password` with your real credentials.

💡 **Tip:** Compass also supports opening an SSH tunnel directly in its **Advanced Connection Options** → this merges steps 2 & 3 into a single action.

---

# 🔄 Updating the Server

To quickly update your server to the latest version of the REST API, simply pull the newest Docker image from Docker Hub.

```bash
docker pull redduality/wyd-rest-server:latest
```

This ensures your deployment runs the most recent release of **WYD Rest Server** without needing a full redeployment.

---
