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

Once you have the file prepared, run the installation script:

```bash
# From infra/ directory
cd infra
./remote-install.sh <target-host>

# The script will:
# 1. Check for gh_pat in current/home directories
# 2. Validate the file exists and is not empty
# 3. Copy it to /run/secrets/ on the remote system
# 4. Configure GitHub Actions Runners to use the PAT
---

## 🤖 GitHub Actions Runners

**See**: `README-github-runners.md` for GitHub runner setup and management.

The runners will automatically:
- Use the PAT from `/run/secrets/gh_pat` to authenticate with GitHub
- Register as ephemeral runners
- Clean up after each workflow run
