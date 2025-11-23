# Cloud Engineering Foundations: Day 1 - Local Cloud Environment Setup

## 🎯 Ultimate Objective

Transform your local machine into a cloud engineering playground. By the end of Day 1, you'll have a professional-grade local cloud environment that mirrors real-world cloud infrastructure. This foundation will enable you to understand, build, and deploy cloud-native applications with confidence.

---

## 🚀 Phase 1: Docker Mastery - Your Local Cloud Foundation

### Why Docker is Your Cloud Gateway

Docker containers are the fundamental building blocks of modern cloud infrastructure. They package applications and dependencies into portable, isolated units that run consistently across any environment - exactly like cloud services. Understanding Docker is understanding how AWS ECS, Google Cloud Run, Azure Container Instances, and Kubernetes work under the hood.

**Key Concepts You'll Master:**
- Containerization vs Virtualization
- Image layering and optimization
- Container networking
- Volume management
- Multi-stage builds
- Container orchestration basics

### Installation: Docker Desktop

#### Windows Installation

1. **Download Docker Desktop for Windows**
   - Visit: https://www.docker.com/products/docker-desktop/
   - Download the installer (Docker Desktop Installer.exe)
   - File size: ~500MB

2. **System Requirements Check**
   - Windows 10 64-bit: Pro, Enterprise, or Education (Build 19041 or higher)
   - Windows 11 64-bit: Home or Pro version 21H2 or higher
   - WSL 2 feature enabled
   - Virtualization enabled in BIOS
   - At least 4GB RAM (8GB+ recommended)
   - Hardware virtualization support (Intel VT-x or AMD-V)

3. **Installation Steps**
   - Run the installer as Administrator
   - Accept the license agreement
   - Ensure "Use WSL 2 instead of Hyper-V" is checked (recommended)
   - Click "Ok" to install
   - Restart your computer when prompted

4. **Post-Installation Verification**
   - Launch Docker Desktop from Start Menu
   - Wait for Docker to start (whale icon in system tray)
   - Open PowerShell or Command Prompt
   - Run verification command:
     ```
     docker --version
     ```
   - Expected output: `Docker version 24.x.x, build xxxxx`
   - Run:
     ```
     docker info
     ```
   - Should display detailed Docker system information without errors

#### macOS Installation

1. **Download Docker Desktop for Mac**
   - Visit: https://www.docker.com/products/docker-desktop/
   - Choose Intel Chip or Apple Silicon version based on your Mac
   - Download the .dmg file

2. **System Requirements**
   - macOS 11 or newer (Big Sur or later)
   - At least 4GB RAM
   - VirtualBox prior to version 4.3.30 must NOT be installed

3. **Installation Steps**
   - Open the downloaded .dmg file
   - Drag Docker.app to Applications folder
   - Open Docker from Applications
   - Click "Open" when macOS asks for confirmation
   - Enter your password to install networking components
   - Wait for Docker to start (whale icon in menu bar)

4. **Post-Installation Verification**
   - Open Terminal
   - Run:
     ```
     docker --version
     ```
   - Run:
     ```
     docker info
     ```

#### Linux Installation

For Ubuntu/Debian:

1. **Update package index**
   ```
   sudo apt-get update
   ```

2. **Install prerequisites**
   ```
   sudo apt-get install ca-certificates curl gnupg lsb-release
   ```

3. **Add Docker's official GPG key** (using official Docker documentation method)
   ```
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

4. **Set up repository**
   ```
   ARCH=$(dpkg --print-architecture)
   CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
   echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```

5. **Install Docker Engine**
   ```
   sudo apt-get update
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

6. **Start Docker**
   ```
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

7. **Add user to docker group (optional, to avoid sudo)**
   ```
   sudo usermod -aG docker $USER
   ```
   - Log out and log back in for changes to take effect

### Docker Fundamentals: Your First Commands

#### Test Container Execution

Run your first container to verify Docker is working:

```
docker run hello-world
```

**What happens:**
1. Docker checks if `hello-world` image exists locally
2. If not, it pulls from Docker Hub (public registry)
3. Creates a container from the image
4. Runs the container
5. Container prints a message and exits

**Expected Output:**
```
Hello from Docker!
This message shows that your installation appears to be working correctly.
...
```

#### Understanding Container Lifecycle

**List running containers:**
```
docker ps
```

**List all containers (including stopped):**
```
docker ps -a
```

**List Docker images:**
```
docker images
```

**Stop a running container:**
```
docker stop <container-id>
```

**Remove a container:**
```
docker rm <container-id>
```

**Remove an image:**
```
docker rmi <image-name>
```

### Running Your First Web Server Container

#### Start an Nginx Web Server

Nginx is a production-grade web server used by millions of websites. Running it in Docker simulates deploying a web service to the cloud.

**Run Nginx in detached mode:**
```
docker run -d -p 8080:80 --name my-nginx nginx
```

**Command Breakdown:**
- `docker run` - Create and start a container
- `-d` - Detached mode (runs in background)
- `-p 8080:80` - Port mapping (host:container)
  - Port 8080 on your machine → Port 80 in container
- `--name my-nginx` - Give container a friendly name
- `nginx` - Image name (pulls from Docker Hub if not local)

**Verify it's running:**
```
docker ps
```

**View container logs:**
```
docker logs my-nginx
```

**Access the web server:**
- Open your browser
- Navigate to: http://localhost:8080
- You should see the Nginx welcome page

**Stop the container:**
```
docker stop my-nginx
```

**Start it again:**
```
docker start my-nginx
```

**Remove the container:**
```
docker rm -f my-nginx
```

### Advanced Container Operations

#### Interactive Container Access

**Run a container with interactive shell:**
```
docker run -it ubuntu /bin/bash
```

**What this does:**
- `-it` - Interactive terminal
- `ubuntu` - Base Ubuntu image
- `/bin/bash` - Command to run (bash shell)

**Inside the container:**
- You're now in a Linux environment
- Try: `ls`, `pwd`, `whoami`, `apt update`
- Type `exit` to leave

#### Container Resource Limits

**Run with memory limit:**
```
docker run -d -m 512m --name limited-nginx nginx
```

**Run with CPU limit:**
```
docker run -d --cpus="1.5" --name cpu-limited-nginx nginx
```

**View resource usage:**
```
docker stats
```

#### Working with Volumes

Volumes persist data beyond container lifecycle - critical for databases and stateful applications.

**Create a named volume:**
```
docker volume create my-data
```

**Run container with volume:**
```
docker run -d -v my-data:/data --name data-container ubuntu
```

**List volumes:**
```
docker volume ls
```

**Inspect volume:**
```
docker volume inspect my-data
```

**Mount host directory:**
```
docker run -d -v C:\Users\YourName\data:/data --name host-mount nginx
```
(Windows path example - use `/path/to/dir` on Linux/Mac)

### Docker Networking Basics

#### Default Networks

**List networks:**
```
docker network ls
```

**Inspect default bridge network:**
```
docker network inspect bridge
```

#### Create Custom Network

**Create a bridge network:**
```
docker network create my-network
```

**Run containers on custom network:**
```
docker run -d --name web1 --network my-network nginx
docker run -d --name web2 --network my-network nginx
```

**Containers on same network can communicate by name:**
- `web1` can reach `web2` using hostname `web2`
- This simulates service discovery in cloud platforms

#### Network Types

**Bridge network (default):**
- Containers on same bridge can communicate
- Isolated from host network

**Host network:**
```
docker run -d --network host nginx
```
- Container uses host's network directly
- No port mapping needed

**None network:**
```
docker run -d --network none nginx
```
- Container has no network access
- Maximum isolation

### Docker Image Management

#### Pulling Images

**Pull specific version:**
```
docker pull nginx:1.23
```

**Pull latest:**
```
docker pull nginx:latest
```

**Search Docker Hub:**
```
docker search python
```

#### Image Inspection

**Inspect image details:**
```
docker inspect nginx
```

**View image history:**
```
docker history nginx
```

**View image size:**
```
docker images
```

#### Tagging Images

**Tag an image:**
```
docker tag nginx:latest my-nginx:v1.0
```

**This creates a new tag pointing to same image (no copy)**

#### Building Your First Image

Create a simple web app:

**1. Create project directory:**
```
mkdir my-first-app
cd my-first-app
```

**2. Create `index.html`:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>My First Containerized App</title>
</head>
<body>
    <h1>Hello from Docker!</h1>
    <p>This is running in a container.</p>
</body>
</html>
```

**3. Create `Dockerfile`:**
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**4. Build the image:**
```
docker build -t my-first-app:1.0 .
```

**5. Run your custom image:**
```
docker run -d -p 8081:80 --name my-app my-first-app:1.0
```

**6. Visit http://localhost:8081**

**Dockerfile Explanation:**
- `FROM` - Base image
- `COPY` - Copy files into image
- `EXPOSE` - Document which port app uses
- `CMD` - Command to run when container starts

### Docker Compose: Multi-Container Applications

Docker Compose lets you define and run multi-container applications - essential for microservices.

#### Installation

Docker Desktop includes Docker Compose. Verify:
```
docker compose version
```

#### Your First Compose File

**Create `docker-compose.yml`:**
```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
  
  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

**Start services:**
```
docker compose up -d
```

**View running services:**
```
docker compose ps
```

**View logs:**
```
docker compose logs
```

**Stop services:**
```
docker compose down
```

**Stop and remove volumes:**
```
docker compose down -v
```

---

## 🖥️ Phase 2: Virtualization & Hypervisors (Optional but Recommended)

### Why Virtualization Matters

Virtual machines (VMs) are the foundation of Infrastructure as a Service (IaaS). Understanding VMs helps you understand:
- AWS EC2 instances
- Google Compute Engine
- Azure Virtual Machines
- How cloud providers manage compute resources

### Windows: Hyper-V Setup

#### Enable Hyper-V

**1. Check if Hyper-V is available:**
```
systeminfo
```
Look for "Hyper-V Requirements" section

**2. Enable Hyper-V (PowerShell as Administrator):**
```
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

**3. Restart computer**

**4. Verify installation:**
```
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

#### Create Your First VM

**1. Open Hyper-V Manager**
- Search "Hyper-V Manager" in Start Menu

**2. Create Virtual Switch**
- Right-click your computer name
- Virtual Switch Manager
- Create External Virtual Switch
- Name it "External Switch"

**3. Create VM**
- Right-click → New → Virtual Machine
- Name: "Cloud-Learning-VM"
- Generation: Generation 2 (UEFI)
- Memory: 2048 MB (adjust based on your RAM)
- Configure Networking: Select your virtual switch
- Connect Virtual Hard Disk: Create new, 40 GB
- Installation Options: Install from ISO (download Ubuntu Server ISO)

**4. Start and Install**
- Right-click VM → Connect
- Start the VM
- Follow Ubuntu installation wizard

**Key Learning Points:**
- VM isolation (each VM is independent)
- Resource allocation (CPU, RAM, disk)
- Network configuration
- Storage management

### macOS: VirtualBox Setup

#### Install VirtualBox

**1. Download:**
- Visit: https://www.virtualbox.org/wiki/Downloads
- Download for macOS hosts

**2. Install:**
- Open .dmg file
- Run installer
- May require System Preferences approval

**3. Create VM:**
- Open VirtualBox
- Click "New"
- Name: "Cloud-Learning-VM"
- Type: Linux
- Version: Ubuntu (64-bit)
- Memory: 2048 MB
- Create virtual hard disk: VDI, Dynamically allocated, 40 GB

**4. Configure VM:**
- Select VM → Settings
- Storage → Empty → Choose disk file (Ubuntu ISO)
- Network → Adapter 1 → NAT or Bridged Adapter

**5. Start and Install:**
- Start VM
- Follow Ubuntu installation

### Linux: KVM/QEMU Setup

#### Install KVM

**Ubuntu/Debian:**
```
sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
```

**Add user to libvirt group:**
```
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

**Log out and back in**

**Verify:**
```
virsh list --all
```

#### Create VM with virt-manager

**1. Open Virtual Machine Manager:**
```
virt-manager
```

**2. Create new VM:**
- File → New Virtual Machine
- Local install media
- Browse to Ubuntu ISO
- Configure resources
- Finish

---

## 🐍 Phase 3: Python & Development Environment

### Why Python for Cloud Engineering

Python is the lingua franca of cloud engineering:
- AWS SDK (boto3)
- Google Cloud SDK
- Azure SDK
- Terraform (infrastructure as code)
- Ansible (configuration management)
- Kubernetes Python client
- Most cloud automation tools

### Python Installation

#### Windows

**1. Download Python:**
- Visit: https://www.python.org/downloads/
- Download latest Python 3.11 or 3.12
- **CRITICAL:** Check "Add Python to PATH" during installation

**2. Verify Installation:**
```
python --version
pip --version
```

**3. If not in PATH:**
- Add manually:
  - `C:\Users\YourName\AppData\Local\Programs\Python\Python3xx`
  - `C:\Users\YourName\AppData\Local\Programs\Python\Python3xx\Scripts`

#### macOS

**Option 1: Official Installer**
- Download from python.org
- Run installer
- Verify: `python3 --version`

**Option 2: Homebrew (Recommended)**
```
brew install python3
```

#### Linux

**Ubuntu/Debian:**
```
sudo apt update
sudo apt install python3 python3-pip python3-venv
```

**Verify:**
```
python3 --version
pip3 --version
```

### Virtual Environments: Isolation Mastery

Virtual environments are like containers for Python - they isolate dependencies, preventing conflicts.

#### Create Virtual Environment

**Windows:**
```
python -m venv cloud-env
```

**macOS/Linux:**
```
python3 -m venv cloud-env
```

#### Activate Virtual Environment

**Windows (PowerShell):**
```
.\cloud-env\Scripts\Activate.ps1
```

**Windows (Command Prompt):**
```
cloud-env\Scripts\activate.bat
```

**macOS/Linux:**
```
source cloud-env/bin/activate
```

**You'll see `(cloud-env)` prefix in your terminal**

#### Deactivate

```
deactivate
```

### Essential Python Packages for Cloud Engineering

#### Install Cloud SDKs

**AWS SDK (boto3):**
```
pip install boto3
```

**Google Cloud SDK:**
```
pip install google-cloud-storage google-cloud-compute
```

**Azure SDK:**
```
pip install azure-storage-blob azure-identity
```

#### Infrastructure as Code Tools

**Terraform (via pip):**
```
pip install terraform
```

**Ansible:**
```
pip install ansible
```

#### Container Tools

**Docker SDK:**
```
pip install docker
```

**Kubernetes Python Client:**
```
pip install kubernetes
```

#### Utility Libraries

**Requests (HTTP library):**
```
pip install requests
```

**PyYAML (YAML parsing):**
```
pip install pyyaml
```

**Click (CLI framework):**
```
pip install click
```

### Your First Cloud Automation Script

**Create `test-docker.py`:**
```python
import docker

# Create Docker client
client = docker.from_env()

# List all containers
print("Running containers:")
for container in client.containers.list():
    print(f"  - {container.name}: {container.status}")

# List all images
print("\nAvailable images:")
for image in client.images.list():
    print(f"  - {image.tags}")

# Pull an image
print("\nPulling nginx image...")
client.images.pull('nginx:alpine')
print("Done!")
```

**Run it:**
```
python test-docker.py
```

**This demonstrates:**
- Programmatic container management
- API-based infrastructure control
- Foundation for automation scripts

### Requirements File Management

**Create `requirements.txt`:**
```
boto3>=1.28.0
docker>=6.1.0
requests>=2.31.0
pyyaml>=6.0
kubernetes>=28.0.0
```

**Install from requirements:**
```
pip install -r requirements.txt
```

**Export current environment:**
```
pip freeze > requirements.txt
```

---

## 🐧 Phase 4: WSL2 - Linux Environment on Windows

### Why WSL2 for Cloud Engineering

WSL2 (Windows Subsystem for Linux) provides:
- Native Linux environment on Windows
- Better Docker performance
- Access to Linux tools and utilities
- Production-like development environment
- Most cloud services run Linux

### WSL2 Installation

#### Prerequisites

- Windows 10 version 2004 or higher (Build 19041+)
- Windows 11 (any version)
- 64-bit system
- Virtualization enabled in BIOS

#### Installation Steps

**1. Open PowerShell as Administrator:**
- Right-click Start Menu
- Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

**2. Install WSL2:**
```
wsl --install
```

**This command:**
- Enables required Windows features
- Downloads and installs Ubuntu (default)
- Sets WSL2 as default version
- Configures everything automatically

**3. Restart your computer**

**4. After restart:**
- Ubuntu will launch automatically
- Create a username and password
- This is your Linux user (can be different from Windows user)

#### Manual Installation (if needed)

**Enable WSL feature:**
```
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```

**Enable Virtual Machine Platform:**
```
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

**Restart computer**

**Set WSL2 as default:**
```
wsl --set-default-version 2
```

**Install Ubuntu:**
```
wsl --install -d Ubuntu
```

### WSL2 Configuration

#### Update Ubuntu

**Inside WSL2:**
```
sudo apt update
sudo apt upgrade -y
```

#### Install Essential Tools

```
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    docker.io
```

#### Configure Git

```
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### WSL2 and Docker Integration

#### Docker Desktop Integration

Docker Desktop automatically integrates with WSL2:
- No additional configuration needed
- Docker commands work in WSL2
- Better performance than Docker on Windows directly

**Verify:**
```
docker --version
docker ps
```

#### Alternative: Docker in WSL2

**Install Docker in WSL2:**
```
sudo apt install docker.io
sudo service docker start
sudo usermod -aG docker $USER
```

**Log out and back in**

**Verify:**
```
docker run hello-world
```

### WSL2 File System Access

#### Access Windows Files from WSL2

Windows drives are mounted under `/mnt/`:
```
cd /mnt/c/Users/YourName/Documents
```

#### Access WSL2 Files from Windows

WSL2 files are accessible via:
```
\\wsl$\Ubuntu\home\yourusername
```

Or in File Explorer address bar:
```
\\wsl$\Ubuntu
```

### WSL2 Networking

#### Localhost Access

Services running in WSL2 are accessible from Windows:
- WSL2 IP changes on each restart
- Use `localhost` from Windows to access WSL2 services
- Use `localhost` from WSL2 to access Windows services

**Find WSL2 IP:**
```
ip addr show eth0
```

#### Port Forwarding

Windows automatically forwards ports from WSL2 to Windows localhost.

---

## 🗄️ Phase 5: Local Database Setup

### Why Local Databases Matter

Most cloud applications use databases. Running databases locally helps you:
- Understand database concepts
- Test applications before cloud deployment
- Learn SQL and NoSQL
- Practice database administration

### PostgreSQL Setup

#### Using Docker (Recommended)

**Run PostgreSQL container:**
```
docker run -d \
  --name postgres-cloud \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=clouddb \
  -e POSTGRES_USER=clouduser \
  -p 5432:5432 \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

**Connect to database:**
```
docker exec -it postgres-cloud psql -U clouduser -d clouddb
```

**Basic SQL commands:**
```sql
-- List databases
\l

-- List tables
\dt

-- Create table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

-- Insert data
INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');

-- Query data
SELECT * FROM users;

-- Exit
\q
```

#### Native Installation

**Windows:**
- Download from: https://www.postgresql.org/download/windows/
- Run installer
- Remember the postgres user password

**macOS:**
```
brew install postgresql@15
brew services start postgresql@15
```

**Linux:**
```
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### MySQL Setup

#### Using Docker

**Run MySQL container:**
```
docker run -d \
  --name mysql-cloud \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=clouddb \
  -e MYSQL_USER=clouduser \
  -e MYSQL_PASSWORD=userpassword \
  -p 3306:3306 \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

**Connect:**
```
docker exec -it mysql-cloud mysql -u clouduser -p
```

### MongoDB Setup (NoSQL)

#### Using Docker

**Run MongoDB container:**
```
docker run -d \
  --name mongo-cloud \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=adminpassword \
  -p 27017:27017 \
  -v mongo-data:/data/db \
  mongo:7
```

**Connect:**
```
docker exec -it mongo-cloud mongosh -u admin -p adminpassword
```

**Basic commands:**
```javascript
// Show databases
show dbs

// Use database
use clouddb

// Create collection and insert
db.users.insertOne({name: "John", email: "john@example.com"})

// Query
db.users.find()

// Exit
exit
```

### Redis Setup (In-Memory Database)

#### Using Docker

**Run Redis container:**
```
docker run -d \
  --name redis-cloud \
  -p 6379:6379 \
  -v redis-data:/data \
  redis:7-alpine redis-server --appendonly yes
```

**Connect:**
```
docker exec -it redis-cloud redis-cli
```

**Basic commands:**
```
SET mykey "Hello Redis"
GET mykey
KEYS *
EXIT
```

---

## 🌐 Phase 6: Object Storage Simulation with MinIO

### Why MinIO

MinIO is S3-compatible object storage. It lets you:
- Learn AWS S3 concepts locally
- Test S3 applications without AWS account
- Understand object storage architecture
- Practice with S3 SDKs

### MinIO Installation

#### Using Docker

**Run MinIO server:**
```
docker run -d \
  --name minio-cloud \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  -v minio-data:/data \
  minio/minio server /data --console-address ":9001"
```

**Access MinIO Console:**
- URL: http://localhost:9001
- Username: minioadmin
- Password: minioadmin

### Using MinIO with Python

**Install MinIO client:**
```
pip install minio
```

**Create test script `test-minio.py`:**
```python
from minio import Minio
from minio.error import S3Error

# Create MinIO client
client = Minio(
    "localhost:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=False
)

# Create bucket
bucket_name = "my-bucket"
try:
    client.make_bucket(bucket_name)
    print(f"Bucket '{bucket_name}' created successfully")
except S3Error as e:
    print(f"Error: {e}")

# Upload file
try:
    client.fput_object(
        bucket_name, "test.txt", "test.txt"
    )
    print("File uploaded successfully")
except S3Error as e:
    print(f"Error: {e}")

# List objects
objects = client.list_objects(bucket_name)
for obj in objects:
    print(f"  - {obj.object_name}")
```

---

## 🔗 Phase 7: Container Networking Deep Dive

### Understanding Docker Networks

#### Network Types Explained

**1. Bridge Network (Default)**
- Containers on same bridge can communicate
- Isolated from host
- Default for standalone containers

**2. Host Network**
- Container shares host's network stack
- No isolation
- Best performance

**3. Overlay Network**
- For Docker Swarm
- Multi-host networking
- Used in orchestration

**4. Macvlan Network**
- Containers get MAC addresses
- Appear as physical devices on network
- Advanced use cases

**5. None Network**
- Complete network isolation
- No network interfaces

### Creating Multi-Container Applications

#### Web + Database Setup

**Create `docker-compose.yml`:**
```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    depends_on:
      - app
    networks:
      - app-network

  app:
    image: python:3.11-alpine
    command: python -m http.server 8000
    volumes:
      - ./app:/app
    networks:
      - app-network

  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
```

**Start everything:**
```
docker compose up -d
```

**Services can communicate using service names:**
- `web` can reach `app` at `http://app:8000`
- `app` can reach `database` at `postgres:5432`
- `app` can reach `redis` at `redis:6379`

### Network Inspection

**Inspect network:**
```
docker network inspect app-network
```

**View network connections:**
```
docker network ls
docker network inspect bridge
```

**Connect container to network:**
```
docker network connect app-network existing-container
```

**Disconnect:**
```
docker network disconnect app-network existing-container
```

---

## 📦 Phase 8: Volume Management

### Understanding Volumes

Volumes persist data beyond container lifecycle - essential for:
- Databases
- File storage
- Configuration files
- Logs

### Volume Types

#### Named Volumes

**Create:**
```
docker volume create my-volume
```

**Use in container:**
```
docker run -d -v my-volume:/data nginx
```

**List volumes:**
```
docker volume ls
```

**Inspect:**
```
docker volume inspect my-volume
```

**Remove:**
```
docker volume rm my-volume
```

#### Bind Mounts

**Mount host directory:**
```
docker run -d -v /host/path:/container/path nginx
```

**Windows example:**
```
docker run -d -v C:\Users\YourName\data:/data nginx
```

**Linux/Mac example:**
```
docker run -d -v /home/user/data:/data nginx
```

#### Anonymous Volumes

Created automatically when you use `-v /path` without name:
```
docker run -d -v /data nginx
```

### Volume Best Practices

**1. Use named volumes for data persistence**
**2. Use bind mounts for development**
**3. Backup volumes regularly**
**4. Don't store secrets in volumes**

### Volume Backup and Restore

**Backup volume:**
```
docker run --rm -v my-volume:/data -v $(pwd):/backup ubuntu tar czf /backup/backup.tar.gz /data
```

**Restore volume:**
```
docker run --rm -v my-volume:/data -v $(pwd):/backup ubuntu tar xzf /backup/backup.tar.gz -C /data
```

---

## 🛠️ Phase 9: Dockerfile Best Practices

### Writing Production-Ready Dockerfiles

#### Multi-Stage Builds

**Example:**
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Benefits:**
- Smaller final image
- No build tools in production
- Better security

#### Layer Optimization

**Bad (creates many layers):**
```dockerfile
RUN apt-get update
RUN apt-get install -y package1
RUN apt-get install -y package2
RUN apt-get install -y package3
```

**Good (single layer):**
```dockerfile
RUN apt-get update && \
    apt-get install -y package1 package2 package3 && \
    rm -rf /var/lib/apt/lists/*
```

#### Security Best Practices

**1. Use specific tags, not `latest`:**
```dockerfile
FROM node:18-alpine
# Not: FROM node:latest
```

**2. Run as non-root user:**
```dockerfile
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser
USER appuser
```

**3. Don't copy secrets:**
```dockerfile
# Use secrets management
# Don't: COPY .env .
```

**4. Use .dockerignore:**
```
node_modules
.git
.env
*.log
```

### Build Optimization

**Build with cache:**
```
docker build -t myapp:1.0 .
```

**Build without cache:**
```
docker build --no-cache -t myapp:1.0 .
```

**Build with build args:**
```dockerfile
ARG NODE_VERSION=18
FROM node:${NODE_VERSION}-alpine
```

```
docker build --build-arg NODE_VERSION=20 -t myapp:1.0 .
```

---

## 🧪 Phase 10: Hands-On Practice Projects

### Project 1: Three-Tier Web Application

**Architecture:**
- deepiri-web-frontend (Nginx)
- Backend (Python Flask)
- Database (PostgreSQL)

**Create project structure:**
```
three-tier-app/
├── deepiri-web-frontend/
│   └── index.html
├── backend/
│   ├── app.py
│   └── requirements.txt
└── docker-compose.yml
```

**`docker-compose.yml`:**
```yaml
version: '3.8'

services:
  deepiri-web-frontend:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./deepiri-web-frontend:/usr/share/nginx/html
    depends_on:
      - backend

  backend:
    build: ./deepiri-core-api
    ports:
      - "5000:5000"
    environment:
      DATABASE_URL: postgresql://user:password@database:5432/myapp
    depends_on:
      - database

  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

**`backend/app.py`:**
```python
from flask import Flask, jsonify
import psycopg2
import os

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host=os.environ['DATABASE_HOST'],
        database=os.environ['DATABASE_NAME'],
        user=os.environ['DATABASE_USER'],
        password=os.environ['DATABASE_PASSWORD']
    )
    return conn

@app.route('/api/health')
def health():
    return jsonify({"status": "healthy"})

@app.route('/api/data')
def get_data():
    # Database query logic here
    return jsonify({"data": "from database"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**`backend/Dockerfile`:**
```dockerfile
FROM python:3.11-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

**Start:**
```
docker compose up --build
```

### Project 2: Microservices with Service Discovery

**Create services that discover each other:**
- Service A (producer)
- Service B (consumer)
- Redis (service registry)

**This teaches:**
- Service discovery patterns
- Inter-service communication
- Microservices architecture

### Project 3: CI/CD Pipeline Simulation

**Set up:**
- Git repository
- Automated builds
- Testing containers
- Deployment simulation

**Tools to explore:**
- GitHub Actions (if using GitHub)
- GitLab CI (if using GitLab)
- Jenkins in Docker

---

## 📊 Phase 11: Monitoring and Observability

### Container Logs

**View logs:**
```
docker logs container-name
```

**Follow logs:**
```
docker logs -f container-name
```

**Last N lines:**
```
docker logs --tail 100 container-name
```

**Since timestamp:**
```
docker logs --since 2024-01-01T00:00:00 container-name
```

### Resource Monitoring

**Real-time stats:**
```
docker stats
```

**Specific container:**
```
docker stats container-name
```

**No-stream (one-time):**
```
docker stats --no-stream
```

### Health Checks

**Add health check to Dockerfile:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:80/ || exit 1
```

**Check health status:**
```
docker inspect --format='{{.State.Health.Status}}' container-name
```

### Logging Drivers

**Configure logging:**
```
docker run --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 nginx
```

**Available drivers:**
- json-file (default)
- syslog
- journald
- gelf
- fluentd
- awslogs

---

## 🔒 Phase 12: Security Fundamentals

### Container Security

#### Run as Non-Root

**In Dockerfile:**
```dockerfile
RUN adduser -D appuser
USER appuser
```

#### Limit Capabilities

**Remove capabilities:**
```
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE nginx
```

#### Read-Only Root Filesystem

```
docker run --read-only -v /tmp nginx
```

#### Security Scanning

**Scan image:**
```
docker scan nginx:alpine
```

**Use Docker Scout (if available):**
```
docker scout quickview nginx:alpine
```

### Secrets Management

#### Environment Variables (Not for Secrets)

**For non-sensitive config:**
```yaml
environment:
  - APP_ENV=production
```

#### Docker Secrets (Swarm)

**Create secret:**
```
echo "mysecret" | docker secret create my_secret -
```

**Use in service:**
```yaml
secrets:
  - my_secret
```

#### External Secrets Management

- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

### Image Security

**1. Use official images**
**2. Keep images updated**
**3. Scan for vulnerabilities**
**4. Use minimal base images (Alpine)**
**5. Don't include secrets in images**

---

## 🎓 Phase 13: Advanced Concepts

### Docker BuildKit

**Enable BuildKit:**
```
export DOCKER_BUILDKIT=1
```

**Or:**
```
DOCKER_BUILDKIT=1 docker build .
```

**Benefits:**
- Faster builds
- Better caching
- Parallel builds
- Secret management

### Docker Swarm (Orchestration Basics)

**Initialize swarm:**
```
docker swarm init
```

**Create service:**
```
docker service create --replicas 3 -p 8080:80 --name web nginx
```

**List services:**
```
docker service ls
```

**Scale service:**
```
docker service scale web=5
```

**Update service:**
```
docker service update --image nginx:1.23 web
```

### Container Registries

#### Docker Hub

**Login:**
```
docker login
```

**Tag image:**
```
docker tag myapp:1.0 username/myapp:1.0
```

**Push:**
```
docker push username/myapp:1.0
```

**Pull:**
```
docker pull username/myapp:1.0
```

#### Private Registry

**Run local registry:**
```
docker run -d -p 5000:5000 --name registry registry:2
```

**Tag for local registry:**
```
docker tag myapp:1.0 localhost:5000/myapp:1.0
```

**Push:**
```
docker push localhost:5000/myapp:1.0
```

---

## ✅ Day 1 Completion Checklist

### Core Setup
- [ ] Docker Desktop installed and running
- [ ] Successfully ran `hello-world` container
- [ ] Nginx container running and accessible
- [ ] Python installed and verified
- [ ] Virtual environment created and activated
- [ ] WSL2 installed (Windows users)

### Skills Demonstrated
- [ ] Created custom Docker image
- [ ] Built multi-container application with Docker Compose
- [ ] Configured container networking
- [ ] Managed volumes and persistent storage
- [ ] Ran database containers (PostgreSQL/MySQL/MongoDB)
- [ ] Set up MinIO for object storage
- [ ] Wrote Python script to interact with Docker API

### Understanding Achieved
- [ ] Understand difference between images and containers
- [ ] Understand port mapping and networking
- [ ] Understand volumes and data persistence
- [ ] Understand Dockerfile structure
- [ ] Understand Docker Compose for multi-container apps
- [ ] Understand container lifecycle (create, start, stop, remove)

### Projects Completed
- [ ] Simple web server container
- [ ] Custom application container
- [ ] Multi-container application
- [ ] Database-backed application

---

## 🚀 Day 2 Preview: What's Next

### Advanced Networking
- Custom network topologies
- Service mesh concepts
- Load balancing

### Orchestration
- Kubernetes basics
- Container orchestration patterns
- Service discovery

### Infrastructure as Code
- Terraform introduction
- Ansible basics
- CloudFormation overview

### Cloud Services Simulation
- LocalStack (AWS services)
- LocalStack alternatives
- Cloud service emulation

### CI/CD Foundations
- GitHub Actions
- GitLab CI
- Jenkins basics

### Monitoring Stack
- Prometheus
- Grafana
- ELK Stack (Elasticsearch, Logstash, Kibana)

---

## 🐛 Troubleshooting Guide

### Docker Issues

#### Docker won't start
**Windows:**
- Ensure WSL2 is installed and updated
- Check Hyper-V is enabled
- Restart Docker Desktop
- Check Windows updates

**macOS:**
- Ensure virtualization is enabled
- Check system resources
- Restart Docker Desktop

**Linux:**
- Check Docker service: `sudo systemctl status docker`
- Start Docker: `sudo systemctl start docker`
- Check permissions: `sudo usermod -aG docker $USER`

#### Containers can't access internet
- Check DNS settings
- Verify network configuration
- Check firewall settings

#### Port already in use
- Find process using port:
  - Windows: `netstat -ano | findstr :8080`
  - Linux/Mac: `lsof -i :8080`
- Stop the process or use different port

#### Out of disk space
- Clean up unused images: `docker system prune -a`
- Remove unused volumes: `docker volume prune`
- Check disk space: `docker system df`

### Python Issues

#### Python not found
- Verify installation
- Check PATH environment variable
- Use `python3` instead of `python` on some systems

#### pip not found
- Install pip: `python -m ensurepip --upgrade`
- Or: `python -m pip install --upgrade pip`

#### Virtual environment not activating
- Check you're in correct directory
- Verify activation script exists
- Use full path to activation script

### WSL2 Issues

#### WSL2 not starting
- Update WSL: `wsl --update`
- Set default version: `wsl --set-default-version 2`
- Check Windows features are enabled

#### Slow file system access
- Store files in WSL2 filesystem, not Windows
- Use `/home/username` instead of `/mnt/c`

#### Docker commands not working in WSL2
- Ensure Docker Desktop is running
- Verify WSL2 integration in Docker Desktop settings
- Restart WSL2: `wsl --shutdown`

---

## 📚 Additional Learning Resources

### Official Documentation
- Docker Documentation: https://docs.docker.com/
- Python Documentation: https://docs.python.org/3/
- WSL2 Documentation: https://docs.microsoft.com/windows/wsl/

### Interactive Learning
- Docker Labs: https://labs.play-with-docker.com/
- Katacoda (if still available)
- Docker Official Tutorials

### Books
- "Docker Deep Dive" by Nigel Poulton
- "The Docker Book" by James Turnbull
- "Cloud Native Patterns" by Cornelia Davis

### Video Courses
- Docker Official Training
- Pluralsight Docker courses
- Udemy Docker courses

### Communities
- Docker Community Forums
- Reddit: r/docker
- Stack Overflow (docker tag)

---

## 🎯 Key Takeaways

1. **Containers are the foundation** of modern cloud infrastructure
2. **Docker Compose** enables complex multi-container applications
3. **Virtual environments** isolate Python dependencies
4. **WSL2** provides Linux environment on Windows
5. **Local databases** let you practice without cloud costs
6. **MinIO** simulates S3 object storage locally
7. **Networking** is crucial for microservices
8. **Volumes** persist data beyond container lifecycle
9. **Security** must be considered from the start
10. **Practice projects** solidify understanding

---

## 💡 Pro Tips

1. **Use Docker Compose for everything** - it's easier to manage
2. **Always use specific image tags** - avoid `latest` in production
3. **Keep Dockerfiles minimal** - smaller images = faster deployments
4. **Use .dockerignore** - exclude unnecessary files
5. **Monitor resource usage** - containers can consume lots of resources
6. **Backup volumes regularly** - data persistence is critical
7. **Learn one thing at a time** - don't try to learn everything at once
8. **Practice daily** - consistency beats intensity
9. **Read error messages carefully** - they usually tell you what's wrong
10. **Join communities** - learning with others accelerates growth

---

## 🏆 Congratulations!

You've completed Day 1 of your cloud engineering journey. You now have:

- A fully functional local cloud environment
- Understanding of containerization fundamentals
- Python development environment
- Database and storage systems running locally
- Foundation for advanced cloud concepts

**You're ready for Day 2!**

Remember: Cloud engineering is a journey, not a destination. Keep practicing, keep building, and keep learning.

---

**Last Updated:** 2025-01-14  
**Next Steps:** Begin Day 2 - Advanced Orchestration and Infrastructure as Code





