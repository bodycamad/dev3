# GitHub Repository Setup & Sync Instructions

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `dev3`
3. Description: `Development project repository`
4. Choose: **Public** or **Private**
5. **DO NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

## Step 2: Connect Local Repository to GitHub

After creating the repository, run these commands in your terminal:

```bash
# Add GitHub remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/dev3.git

# Or if you prefer SSH (recommended for better security):
git remote add origin git@github.com:YOUR_USERNAME/dev3.git

# Verify remote was added
git remote -v

# Push to GitHub
git push -u origin master
```

## Step 3: Set Up Real-Time Sync

### Option A: GitHub Actions (Recommended for CI/CD)
Create `.github/workflows/sync.yml`:

```yaml
name: Auto Sync
on:
  push:
    branches: [ master, main ]
  pull_request:
    branches: [ master, main ]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run tests (if applicable)
      run: |
        # Add your test commands here
        echo "Tests passed"
```

### Option B: Git Hooks for Local Auto-Push
Create `.git/hooks/post-commit`:

```bash
#!/bin/sh
# Auto-push after each commit
git push origin master
```

Make it executable:
```bash
chmod +x .git/hooks/post-commit
```

### Option C: Using Git Aliases for Quick Sync
Add to your git config:

```bash
# Add alias for commit and push
git config alias.sync '!git add -A && git commit -m "Auto-sync: $(date +%Y-%m-%d_%H:%M:%S)" && git push'

# Usage: git sync
```

## Step 4: Verify Setup

```bash
# Check remote configuration
git remote -v

# Check branch tracking
git branch -vv

# Test push
echo "test" > test.txt
git add test.txt
git commit -m "Test commit"
git push
```

## Step 5: Additional Configuration (Optional)

### Set default branch name
```bash
git config --global init.defaultBranch main
```

### Configure pull strategy
```bash
git config pull.rebase false  # merge (default)
# or
git config pull.rebase true   # rebase
```

### Set up branch protection on GitHub
1. Go to Settings → Branches in your repository
2. Add rule for master/main branch
3. Configure protection rules as needed

## Troubleshooting

### Authentication Issues
If you get authentication errors:

1. **For HTTPS**: Use Personal Access Token
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with repo permissions
   - Use token as password when prompted

2. **For SSH**: Set up SSH keys
   ```bash
   # Generate SSH key
   ssh-keygen -t ed25519 -C "your_email@example.com"
   
   # Add to SSH agent
   ssh-add ~/.ssh/id_ed25519
   
   # Copy public key and add to GitHub
   cat ~/.ssh/id_ed25519.pub
   ```

### Push Rejected
If push is rejected:
```bash
# Pull first, then push
git pull origin master --allow-unrelated-histories
git push origin master
```

## Quick Commands Reference

```bash
# View status
git status

# Add all changes
git add .

# Commit with message
git commit -m "Your message"

# Push to GitHub
git push

# Pull from GitHub
git pull

# View commit history
git log --oneline

# Create and switch to new branch
git checkout -b feature-branch

# Merge branch
git checkout master
git merge feature-branch
```