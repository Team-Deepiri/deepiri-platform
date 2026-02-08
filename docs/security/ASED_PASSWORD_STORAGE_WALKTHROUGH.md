# ASED Detonator Password Setup Guide

## The Core Problem

**Question**: "How do I set up the local password?"

**The Problem**: 
- The ASED (Autonomous Sovereignty Enforcement Detonator) system needs a password to control/disarm it
- The password is: `joeblackthemonster`
- This password must be **automatically available** to ASED without manual entry
- It must be stored **locally** (not in GitHub, not requiring manual `.env` files)
- It should be stored in **multiple locations** for redundancy
- It should be **automatically inserted** into scripts during normal development workflows


## Solution Overview

Store the ASED detonator password in **multiple hidden locations** and automatically inject it into scripts that run during normal development:

1. **Hidden files** in the repository (gitignored)
2. **Script-embedded** functions in setup scripts
3. **Environment variable injection** via k8s loaders
4. **Automatic creation** during setup workflows

## Storage Locations

### Primary Storage: Hidden File

**Location**: `.deepiri/ased-detonator-password`

This is the primary storage location - a hidden file in the repository root.

**Properties**:
- Hidden directory (starts with dot)
- Gitignored (never committed)
- Restricted permissions (600 - owner read/write only)
- Automatically created by setup scripts

### Secondary Storage: Script-Embedded

**Locations**:
- `setup-hooks.sh` - Main setup script
- `team_submodule_commands/*/pull_submodules.sh` - Submodule scripts
- `team_dev_environments/*/start.sh` - Team start scripts
- `team_dev_environments/shared/k8s_env_loader.py` - Python loader

**Properties**:
- Password embedded as a function/variable
- Serves as fallback if file is missing
- Automatically exports as environment variable

### Tertiary Storage: Environment Variable

**Injection Points**:
- `team_dev_environments/shared/k8s_env_loader.py` - Loads from file and injects
- `docker-compose-k8s.sh` - Wrapper script exports to environment
- `setup-hooks.sh` - Exports during setup

**Properties**:
- Available as `ASED_DETONATOR_PASSWORD` environment variable
- Highest priority (checked first)
- Runtime override capability

## Step-by-Step Setup Process

### Step 1: Create Hidden Directory

From the repository root:

```bash
mkdir -p .deepiri
```

### Step 2: Create Password File

Create the password file with the actual password:

```bash
echo "joeblackthemonster" > .deepiri/ased-detonator-password
chmod 600 .deepiri/ased-detonator-password
```

**Verify it was created**:
```bash
ls -la .deepiri/ased-detonator-password
# Should show: -rw------- (600 permissions)
```

### Step 3: Add to .gitignore

Ensure the password file is never committed:

```bash
echo ".deepiri/ased-detonator-password" >> .gitignore
```

**Verify it's ignored**:
```bash
git check-ignore .deepiri/ased-detonator-password
# Should output: .deepiri/ased-detonator-password
```

### Step 4: Modify setup-hooks.sh

Add password creation and export logic to `setup-hooks.sh`:

```bash
# Function to ensure ASED detonator password file exists
ensure_ased_detonator_password() {
    local password_file=".deepiri/ased-detonator-password"
    local password="joeblackthemonster"
    
    # Create directory if it doesn't exist
    mkdir -p .deepiri
    
    # Create password file if it doesn't exist
    if [ ! -f "$password_file" ]; then
        echo "Creating ASED detonator password file..."
        echo "$password" > "$password_file"
        chmod 600 "$password_file"
        echo "✅ ASED detonator password file created at $password_file"
    fi
    
    # Export password as environment variable
    if [ -f "$password_file" ]; then
        export ASED_DETONATOR_PASSWORD=$(cat "$password_file")
    else
        # Fallback to embedded password
        export ASED_DETONATOR_PASSWORD="$password"
    fi
    
    echo "✅ ASED detonator password available as ASED_DETONATOR_PASSWORD"
}

# Call this function early in setup-hooks.sh
ensure_ased_detonator_password
```

### Step 5: Modify pull_submodules.sh Scripts

For each team's `pull_submodules.sh` script in `team_submodule_commands/*/pull_submodules.sh`:

Add the same `ensure_ased_detonator_password` function and call it after determining the repository root:

```bash
# After: cd "$REPO_ROOT"
# Add:

# Ensure ASED detonator password is available
ensure_ased_detonator_password
```

**Example location in script**:
```bash
cd "$REPO_ROOT"

# Ensure ASED detonator password is available
ensure_ased_detonator_password

# Continue with submodule operations...
```

### Step 6: Modify k8s_env_loader.py

Update `team_dev_environments/shared/k8s_env_loader.py` to load the password:

```python
import os
from pathlib import Path

def load_ased_detonator_password(project_root=None):
    """Load ASED detonator password from hidden file or embedded fallback"""
    if project_root is None:
        script_dir = Path(__file__).parent
        project_root = script_dir.parent.parent
    else:
        project_root = Path(project_root)
    
    password_file = project_root / '.deepiri' / 'ased-detonator-password'
    
    # First, check environment variable (highest priority)
    if 'ASED_DETONATOR_PASSWORD' in os.environ:
        return os.environ['ASED_DETONATOR_PASSWORD']
    
    # Second, check hidden file
    if password_file.exists():
        try:
            with open(password_file, 'r') as f:
                password = f.read().strip()
            os.environ['ASED_DETONATOR_PASSWORD'] = password
            return password
        except Exception as e:
            print(f"{YELLOW}   ⚠️  Warning: Could not read ASED detonator password file: {e}{RESET}")
    
    # Third, fallback to embedded password
    fallback_password = "joeblackthemonster"
    os.environ['ASED_DETONATOR_PASSWORD'] = fallback_password
    return fallback_password

def load_all_configmaps_and_secrets(project_root=None):
    """Load all ConfigMaps and Secrets from ops/k8s/"""
    # ... existing code ...
    
    # Load ASED detonator password
    ased_password = load_ased_detonator_password(project_root)
    all_env_vars['ASED_DETONATOR_PASSWORD'] = ased_password
    
    return all_env_vars
```

### Step 7: Modify start.sh Scripts (Optional)

For team-specific `start.sh` scripts in `team_dev_environments/*/start.sh`:

Add password loading near the top:

```bash
# Load ASED detonator password if file exists
ASED_PASSWORD_FILE=".deepiri/ased-detonator-password"
if [ -f "$ASED_PASSWORD_FILE" ]; then
    export ASED_DETONATOR_PASSWORD=$(cat "$ASED_PASSWORD_FILE")
elif [ -z "$ASED_DETONATOR_PASSWORD" ]; then
    export ASED_DETONATOR_PASSWORD="joeblackthemonster"
fi
```

### Step 8: Modify docker-compose-k8s.sh (If Exists)

If there's a `docker-compose-k8s.sh` wrapper script, add password loading:

```bash
# Load ASED detonator password
ASED_PASSWORD_FILE=".deepiri/ased-detonator-password"
if [ -f "$ASED_PASSWORD_FILE" ]; then
    export ASED_DETONATOR_PASSWORD=$(cat "$ASED_PASSWORD_FILE")
else
    export ASED_DETONATOR_PASSWORD="joeblackthemonster"
fi

# Continue with docker-compose operations...
```

## Using the Password with ASED

Once the password is available as an environment variable, ASED can use it:

### ASED Service Integration

The ASED service should check for the password to allow disarming/control:

```typescript
// ASED service checks for detonator password
const detonatorPassword = process.env.ASED_DETONATOR_PASSWORD;

// When user attempts to disarm ASED
function disarmASED(providedPassword: string): boolean {
    if (providedPassword === detonatorPassword) {
        // Disarm successful
        return true;
    }
    return false;
}
```

### Python Integration

```python
# ASED Python service
import os

detonator_password = os.environ.get('ASED_DETONATOR_PASSWORD', 'joeblackthemonster')

def disarm_ased(provided_password: str) -> bool:
    """Disarm ASED detonator if password matches"""
    if provided_password == detonator_password:
        return True
    return False
```

## Complete Setup Workflow

### For Repository Maintainer (Initial Setup)

```bash
# 1. Create hidden directory
mkdir -p .deepiri

# 2. Create password file
echo "joeblackthemonster" > .deepiri/ased-detonator-password
chmod 600 .deepiri/ased-detonator-password

# 3. Add to .gitignore
echo ".deepiri/ased-detonator-password" >> .gitignore

# 4. Modify scripts (as described above)
# - setup-hooks.sh
# - team_submodule_commands/*/pull_submodules.sh
# - team_dev_environments/shared/k8s_env_loader.py
# - team_dev_environments/*/start.sh (optional)
# - docker-compose-k8s.sh (optional)

# 5. Commit script changes (NOT the password file)
git add setup-hooks.sh team_submodule_commands/ team_dev_environments/ .gitignore
git commit -m "Add automatic ASED detonator password setup"
git push
```

### For Team Members (Automatic Setup)

When a team member clones the repository:

```bash
# 1. Clone repository
git clone https://github.com/Team-Deepiri/deepiri-platform.git
cd deepiri-platform

# 2. Run setup script (automatically creates password file)
./setup-hooks.sh

# 3. Or run submodule script (also creates password file)
cd team_submodule_commands/platform-engineers
./pull_submodules.sh

# 4. Password is now available automatically
# ASED service can now access it via $ASED_DETONATOR_PASSWORD

# No manual password entry needed!
```

**What happens automatically**:
1. Script checks if `.deepiri/ased-detonator-password` exists
2. If not, creates it with the embedded password
3. Sets file permissions to 600
4. Exports as `ASED_DETONATOR_PASSWORD` environment variable
5. ASED service can now access the password for disarming/control

## Password Access Priority

The ASED service should check for the password in this order:

1. **Environment variable** `ASED_DETONATOR_PASSWORD` (highest priority)
2. **Hidden file** `.deepiri/ased-detonator-password`
3. **Script-embedded fallback** (lowest priority)

## File Locations Summary

The password is stored/accessible from:

1. **File**: `.deepiri/ased-detonator-password` (hidden file, gitignored)
2. **Script**: `setup-hooks.sh` (creates file, exports env var)
3. **Scripts**: `team_submodule_commands/*/pull_submodules.sh` (creates file)
4. **Python**: `team_dev_environments/shared/k8s_env_loader.py` (loads from file)
5. **Scripts**: `team_dev_environments/*/start.sh` (optional, loads from file)
6. **Scripts**: `docker-compose-k8s.sh` (optional, loads from file)

## Verification

### Test 1: Check Hidden File Exists

```bash
test -f .deepiri/ased-detonator-password && echo "✅ Password file exists" || echo "❌ Password file missing"
```

### Test 2: Check File Permissions

```bash
ls -la .deepiri/ased-detonator-password
# Should show: -rw------- (600)
```

### Test 3: Check .gitignore

```bash
git check-ignore .deepiri/ased-detonator-password
# Should output: .deepiri/ased-detonator-password
```

### Test 4: Test Script Loading

```bash
# Run setup-hooks.sh and check environment
source setup-hooks.sh
echo $ASED_DETONATOR_PASSWORD
# Should output: joeblackthemonster
```

### Test 5: Test Python Loader

```bash
cd team_dev_environments/platform-engineers
python3 -c "
import sys
sys.path.insert(0, '../shared')
from k8s_env_loader import load_ased_detonator_password
print(load_ased_detonator_password())
"
# Should output: joeblackthemonster
```

## Troubleshooting

### Password File Not Found

**Problem**: ASED service cannot find the password

**Solution**:
1. Verify file exists: `test -f .deepiri/ased-detonator-password`
2. Check file permissions: `ls -la .deepiri/ased-detonator-password`
3. Verify password content: `cat .deepiri/ased-detonator-password`
4. Check environment variable: `echo $ASED_DETONATOR_PASSWORD`
5. Re-run setup script: `./setup-hooks.sh`

### Permission Denied

**Problem**: Cannot read password file

**Solution**:
```bash
chmod 600 .deepiri/ased-detonator-password
```

### File in Wrong Location

**Problem**: Scripts can't find password file

**Solution**: Ensure you're in the repository root when creating the file:
```bash
pwd
# Should show: .../deepiri-platform
```

### Script Not Creating File

**Problem**: Setup script doesn't create password file

**Solution**: Verify the script has the `ensure_ased_detonator_password` function and it's being called:
```bash
grep -n "ensure_ased_detonator_password" setup-hooks.sh
bash -x setup-hooks.sh
```

## Maintenance

### Updating the Password

If the password needs to be changed:

1. Update the hidden file:
   ```bash
   echo "new-password" > .deepiri/ased-detonator-password
   chmod 600 .deepiri/ased-detonator-password
   ```

2. Update script-embedded passwords in:
   - `setup-hooks.sh`
   - `team_submodule_commands/*/pull_submodules.sh`
   - `team_dev_environments/shared/k8s_env_loader.py`
   - Any other scripts with embedded password

3. Update ASED service configuration if needed

4. Test the new password works

### Removing the Password File

If you need to remove the password file (it will be recreated by scripts):

```bash
rm .deepiri/ased-detonator-password
```

The next time you run `setup-hooks.sh` or `pull_submodules.sh`, the file will be recreated automatically.

## Security Notes

1. The password file `.deepiri/ased-detonator-password` is gitignored and should never be committed
2. File permissions are set to 600 (read/write for owner only)
3. The password is stored in plaintext in the hidden file (obfuscation can be added later)
4. Script-embedded password serves as a fallback only
5. Environment variable takes highest priority for runtime override
6. This password controls ASED detonator disarming - keep it secure

## Quick Reference

**Password value**: `joeblackthemonster`

**Primary storage**: `.deepiri/ased-detonator-password`

**Environment variable**: `ASED_DETONATOR_PASSWORD`

**Scripts to modify**:
- `setup-hooks.sh`
- `team_submodule_commands/*/pull_submodules.sh`
- `team_dev_environments/shared/k8s_env_loader.py`
- `team_dev_environments/*/start.sh` (optional)
- `docker-compose-k8s.sh` (optional)

**File permissions**: `600` (rw-------)

**Git status**: Gitignored (never committed)

**Purpose**: Controls/disarms the ASED detonator system

## Summary

This setup provides:

1. **Automatic Creation**: Password file created automatically during setup
2. **Multiple Locations**: Stored in hidden file, scripts, and environment
3. **Zero Manual Entry**: No password typing required
4. **Redundancy**: Multiple fallback mechanisms
5. **Team-Friendly**: Works automatically after clone and setup

**Answer to "How do I set up the local password?"**:

You don't manually set it up - the setup scripts automatically create the password file in `.deepiri/ased-detonator-password` when you run `setup-hooks.sh` or `pull_submodules.sh`. The password is embedded in the scripts as a fallback, and it's automatically exported as `ASED_DETONATOR_PASSWORD` environment variable for the ASED service to use when disarming or controlling the detonator system.
