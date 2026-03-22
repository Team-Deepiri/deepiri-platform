# Platform Engineering Guide

## 👷 Platform Engineering Workspace

This `scripts/` directory is the primary workspace for **Platform Engineering** work. All Docker, infrastructure, deployment, and system management scripts are maintained here.

---

## 🎯 Platform Engineering Responsibilities

### Core Areas
1. **Docker & Container Management**
   - Build scripts
   - Cleanup and maintenance
   - Volume management
   - WSL2 integration

2. **Infrastructure Scripts**
   - Database backups/restores
   - System health checks
   - Deployment automation

3. **Development Tooling**
   - Setup scripts
   - Dependency management
   - Test runners
   - Development utilities

4. **System Maintenance**
   - Disk space management
   - WSL2 virtual disk compaction
   - Docker cleanup automation

---

## 📁 Script Organization

### Docker Management
| Script | Purpose | Maintainer |
|--------|---------|------------|
| `docker-cleanup.sh` | Clean build cache and unused images | Platform Engineering |
| `docker-manager.sh` | General Docker utilities | Platform Engineering |
| `nuke_volumes.sh` | Remove all Docker volumes | Platform Engineering |

### Build & Rebuild
| Script | Purpose | Maintainer |
|--------|---------|------------|
| `rebuild-fresh.sh` (root) | Complete rebuild workflow | Platform Engineering |

### WSL2 & Disk Management
| Script | Purpose | Maintainer |
|--------|---------|------------|
| `compact-wsl-disk.bat` | Compact WSL virtual disk | Platform Engineering |
| `compact-wsl-disk.ps1` | PowerShell version | Platform Engineering |
| `compact-wsl-disk.sh` | WSL helper | Platform Engineering |

### Database Operations
| Script | Purpose | Maintainer |
|--------|---------|------------|
| `mongo-backup.sh` | MongoDB backup | Platform Engineering |
| `mongo-restore.sh` | MongoDB restore | Platform Engineering |
| `mongo-init.js` | MongoDB initialization | Platform Engineering |

### Development Tools
| Script | Purpose | Maintainer |
|--------|---------|------------|
| `dev-utils.sh` | Development utilities | Platform Engineering |
| `fix-dependencies.sh` | Fix npm/node issues | Platform Engineering |
| `setup.sh` | Initial project setup | Platform Engineering |
| `test-runner.sh` | Run test suites | Platform Engineering |

---

## 🛠️ Adding New Scripts

### Guidelines
1. **Naming Convention:**
   - Use lowercase with hyphens: `script-name.sh`
   - Be descriptive: `backup-database.sh` not `backup.sh`
   - Include extension: `.sh`, `.bat`, `.ps1`

2. **Script Headers:**
   ```bash
   #!/bin/bash
   # Script Name: Description
   # Purpose: What this script does
   # Usage: ./script-name.sh [options]
   # Maintainer: Platform Engineering
   ```

3. **Documentation:**
   - Add to this README
   - Include usage examples
   - Document any dependencies

4. **Permissions:**
   - Make executable: `chmod +x script-name.sh`
   - Test in WSL2 environment

5. **Error Handling:**
   - Use `set -e` for bash scripts
   - Provide clear error messages
   - Exit with appropriate codes

---

## 🔧 Common Tasks

### Adding a New Docker Cleanup Script
1. Create script in `scripts/` directory
2. Add description to this README
3. Test with `docker system df` before/after
4. Update `README-SCRIPTS.md` in parent directory

### Adding a Database Script
1. Follow naming: `[database]-[action].sh`
2. Include connection string handling
3. Add backup/restore safety checks
4. Document in this README

### Adding a WSL2 Utility
1. Create both `.sh` and `.bat` versions if needed
2. Test path conversions (Windows ↔ WSL)
3. Handle Docker Desktop integration
4. Document Windows-specific requirements

---

## 🧪 Testing Scripts

### Before Committing
```bash
# Test in WSL2
wsl
cd /mnt/c/Users/josep/Documents/AIToolWebsite/Deepiri/deepiri/scripts
bash script-name.sh

# Test error handling
bash script-name.sh --invalid-flag

# Test with Docker stopped
# Test with Docker running
```

### Checklist
- [ ] Script runs without errors
- [ ] Error messages are clear
- [ ] Works in WSL2 environment
- [ ] Windows batch file works (if applicable)
- [ ] Documentation updated
- [ ] No hardcoded paths (use relative paths)

---

## 📋 Maintenance Schedule

### Weekly
- Review disk usage: `docker system df`
- Check for orphaned volumes
- Verify backup scripts are working

### Monthly
- Update Docker base images
- Review and optimize build scripts
- Clean up unused scripts
- Update documentation

### As Needed
- Fix broken scripts
- Add new utilities
- Optimize performance
- Handle WSL2 disk issues

---

## 🚨 Common Issues & Solutions

### Issue: Script fails with "bad interpreter"
**Solution:** Fix line endings
```bash
sed -i 's/\r$//' script.sh
```

### Issue: Docker commands fail in WSL
**Solution:** Ensure Docker Desktop is running
```bash
docker info  # Should not error
```

### Issue: Path issues between Windows/WSL
**Solution:** Use relative paths or convert properly
```bash
# Convert Windows path to WSL
wslpath -u "C:\Users\...\path"
```

### Issue: Permission denied
**Solution:** Make executable
```bash
chmod +x script.sh
```

---

## 📚 Related Documentation

- `../README-SCRIPTS.md` - User-facing script documentation
- `../QUICK-START-SCRIPTS.md` - Quick reference guide
- `../docker-compose.dev.yml` - Docker Compose configuration
- `../GETTING_STARTED.md` - Project setup guide

---

## 👥 Platform Engineering Team

**Primary Maintainer:** Platform Engineering Team

**Contact:** See project main README for team contacts

**Working Hours:** This directory is actively maintained. Check git history for recent changes.

---

## 🔄 Version Control

### Commit Messages
Use clear, descriptive commit messages:
```
feat(scripts): Add nuke_volumes script for complete volume cleanup
fix(scripts): Fix path conversion in rebuild-fresh.bat
docs(scripts): Update platform engineering guide
```

### Branch Strategy
- Create feature branches for new scripts
- Test thoroughly before merging
- Update documentation with PR

---

## 💡 Best Practices

1. **Idempotency:** Scripts should be safe to run multiple times
2. **Safety First:** Destructive operations require confirmation
3. **Clear Output:** Use colors and formatting for readability
4. **Error Recovery:** Provide rollback options when possible
5. **Documentation:** Keep README files updated
6. **Testing:** Test in clean environment before committing

---

## 🎓 Learning Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [WSL2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

---

**Last Updated:** 2025-11-14  
**Maintained By:** Platform Engineering Team

