#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="/home/nuttbme/Documents/git/openCFD"
REPO_URL="https://github.com/nuttbme-dev/openCFD.git"
BRANCH="main"

cd "$REPO_DIR"

echo "======================================"
echo "Git Commit and Push to main"
echo "======================================"
echo

# Check repository
if [[ ! -d ".git" ]]; then
    echo "ERROR: Not a Git repository:"
    echo "$REPO_DIR"
    exit 1
fi

# Ensure origin exists and points to the correct repository
CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"

if [[ -z "$CURRENT_REMOTE" ]]; then
    echo "Adding origin remote:"
    echo "$REPO_URL"
    git remote add origin "$REPO_URL"

elif [[ "$CURRENT_REMOTE" != "$REPO_URL" ]]; then
    echo "Updating origin remote:"
    echo "Old: $CURRENT_REMOTE"
    echo "New: $REPO_URL"
    git remote set-url origin "$REPO_URL"
fi

echo "Remote origin:"
git remote get-url origin
echo

# Switch to main if needed
CURRENT_BRANCH="$(git branch --show-current)"

if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
    echo "Switching to branch: $BRANCH"
    git switch "$BRANCH"
    echo
fi

# Show current changes
echo "Changed files:"
git status --short
echo

# If there are no local changes, only update from remote
if [[ -z "$(git status --porcelain)" ]]; then
    echo "Nothing to commit."
    echo
    echo "Pulling latest changes from origin/main..."
    git pull --rebase origin "$BRANCH"
    echo
    echo "Repository is up to date."
    exit 0
fi

# Ask for commit message
read -r -p "Enter commit message: " COMMIT_MESSAGE

if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo "ERROR: Commit message cannot be empty."
    exit 1
fi

echo
read -r -p "Stage all changed files? [y/N]: " CONFIRM_ADD

if [[ ! "$CONFIRM_ADD" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Stage files
git add --all

echo
echo "Files staged for commit:"
git status --short
echo

read -r -p "Commit these changes? [y/N]: " CONFIRM_COMMIT

if [[ ! "$CONFIRM_COMMIT" =~ ^[Yy]$ ]]; then
    echo "Cancelled before commit."
    exit 0
fi

# Create local commit
git commit -m "$COMMIT_MESSAGE"

echo
echo "Pulling latest changes with rebase..."
git pull --rebase origin "$BRANCH"

echo
read -r -p "Push commit to origin/main? [y/N]: " CONFIRM_PUSH

if [[ ! "$CONFIRM_PUSH" =~ ^[Yy]$ ]]; then
    echo
    echo "Commit was created locally but was not pushed."
    exit 0
fi

echo
echo "Pushing to origin/main..."
git push origin "$BRANCH"

echo
echo "======================================"
echo "Commit and push completed successfully."
echo "======================================"
