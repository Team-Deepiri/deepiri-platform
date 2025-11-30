# Deepiri Developer Workstation Specs

**Purpose:** Full local development for Deepiri (web + native IDE, AI/ML services, Docker, databases, microservices).

---

## Minimum Requirements

| Component | Requirement | Notes |
|-----------|------------|------|
| CPU | Intel i5 13th Gen / AMD Ryzen 5 7600 | 6 cores / 12 threads minimum for Docker + AI workloads |
| RAM | 16 GB DDR4/DDR5 | Handles Docker containers, ML processes, and IDEs |
| Storage | 512 GB SSD NVMe | ~50 GB for Docker images + OS + development files; SSD for speed |
| GPU | Optional: NVIDIA RTX 3060 / 4060 | For ML acceleration (PyTorch / TensorFlow) — optional if not training |
| OS | Windows 11 Pro / Ubuntu 22.04 LTS | Docker + Python + Node compatible |
| Display | 1080p minimum | Dual monitor recommended for productivity |
| Network | Gigabit Ethernet / Wi-Fi 6 | Fast internet for pulling images & updates |

**Estimated Cost:** ~$800–$1,000 (without GPU)  
**With mid-tier GPU (RTX 4060):** ~$1,200–$1,400

---

## Recommended / Comfortable Specs (for heavy AI dev)

| Component | Recommendation |
|-----------|----------------|
| CPU | Intel i7 14th Gen / AMD Ryzen 7 7800X, 8 cores / 16 threads |
| RAM | 32 GB DDR5 |
| Storage | 1 TB SSD NVMe |
| GPU | NVIDIA RTX 4060 / 4070 (AI acceleration) |
| OS | Windows 11 Pro + WSL2 or Ubuntu 22.04 LTS |
| Display | Dual 1440p monitors |
| Network | Gigabit Ethernet |

**Estimated Cost:** ~$1,500–$1,800

---

## Tips to Keep Storage Lean

- Use slim Docker images (`python:3.11-slim`, `node:18-alpine`)  
- Periodically clean old images (`docker system prune -a`)  
- Avoid `--no-cache` unless necessary
