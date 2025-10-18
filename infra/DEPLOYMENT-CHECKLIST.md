# Deployment Checklist

## ⚠️ IMPORTANT: Pre-Installation Requirements

Before running `./remote-install.sh`, you **MUST** prepare the following files in either the current directory or your home directory:

### 1. GitHub PAT File (`gh_pat`)

**Required for**: GitHub Actions Runners to authenticate with GitHub

**File location**: `./gh_pat` or `~/gh_pat`

**File format**: Plain text file containing only your GitHub Personal Access Token
```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**How to create**:
```bash
# Create in current directory (recommended for running remote-install.sh)
echo "ghp_your_token_here" > ./gh_pat
chmod 600 ./gh_pat

# Add to .gitignore to prevent accidental commits
echo "gh_pat" >> .gitignore
```

**To get a GitHub PAT**:
1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `workflow`, `admin:org_hook`
4. Copy and save the token in the `gh_pat` file

---

### 2. GPG Private Key File (`private_DC_ENCODE_key.asc`)

**Required for**: SOPS encryption/decryption and secrets management

**File location**: `./private_DC_ENCODE_key.asc` or `~/private_DC_ENCODE_key.asc`

**File format**: ASCII-armored GPG private key export

**How to create**:
```bash
# Option 1: Export from existing GPG key
gpg --export-secret-keys --armor DC_ENCODE > ./private_DC_ENCODE_key.asc
chmod 600 ./private_DC_ENCODE_key.asc

# Option 2: If you have the key file already, copy it
cp /path/to/your/key.asc ./private_DC_ENCODE_key.asc
chmod 600 ./private_DC_ENCODE_key.asc
```

**Add to .gitignore**:
```bash
echo "private_DC_ENCODE_key.asc" >> .gitignore
```

---

## 🚀 Running Remote Installation

Once you have both files prepared, run the installation script:

```bash
# From infra/ directory
cd infra
./remote-install.sh <target-host>

# The script will:
# 1. Check for gh_pat and private_DC_ENCODE_key.asc in current/home directories
# 2. Validate both files exist and are not empty
# 3. Copy them to /run/secrets/ on the remote system
# 4. Configure GitHub Actions Runners to use the PAT
# 5. Set up SOPS for secrets management
```

---

## 🔐 SOPS Configuration

**Current Status**: ✅ Uses PGP key `DC_ENCODE` for encryption/decryption

### Verify Current Setup:
```bash
# Check PGP key availability
gpg --list-secret-keys DC_ENCODE

# Test SOPS decryption
sops -d secrets/secrets.yaml

# View encrypted content
cat secrets/secrets.yaml
```

### On New System After Installation:

The `remote-install.sh` script automatically:
1. Copies the GPG private key to `/run/secrets/private_DC_ENCODE_key.asc`
2. Imports it into the system GPG keyring
3. Allows SOPS to use it for encryption/decryption

---

## 🤖 GitHub Actions Runners

**See**: `README-github-runners.md` for GitHub runner setup and management.

The runners will automatically:
- Use the PAT from `/run/secrets/gh_pat` to authenticate with GitHub
- Register as ephemeral runners
- Clean up after each workflow run
