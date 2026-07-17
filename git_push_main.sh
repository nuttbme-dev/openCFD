#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="/home/nuttbme/Documents/git/openCFD"
REPO_URL="git@github.com:nuttbme-dev/openCFD.git"
BRANCH="main"

cd "$REPO_DIR"

echo "======================================"
echo "Git Commit and Push to main"
echo "======================================"
echo

if [[ ! -d ".git" ]]; then
    echo "ERROR: Not a Git repository:"
    echo "$REPO_DIR"
    exit 1
fi

# Force SSH remote so Git will not ask for GitHub username/token
CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"

if [[ -z "$CURRENT_REMOTE" ]]; then
    git remote add origin "$REPO_URL"
elif [[ "$CURRENT_REMOTE" != "$REPO_URL" ]]; then
    echo "Updating origin to SSH:"
    echo "$REPO_URL"
    git remote set-url origin "$REPO_URL"
fi

echo "Remote origin:"
git remote get-url origin
echo

CURRENT_BRANCH="$(git branch --show-current)"

if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
    echo "Switching to branch: $BRANCH"
    git switch "$BRANCH"
fi

echo "Changed files:"
git status --short
echo

if [[ -z "$(git status --porcelain)" ]]; then
    echo "Nothing to commit."
    echo "Pulling latest changes..."
    git pull --rebase origin "$BRANCH"
    exit 0
fi

read -r -p "Enter commit message: " COMMIT_MESSAGE

if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo "ERROR: Commit message cannot be empty."
    exit 1
fi

git add --all

echo
echo "Staged files:"
git status --short
echo

git commit -m "$COMMIT_MESSAGE"

echo
echo "Pulling latest changes..."
git pull --rebase origin "$BRANCH"

echo
echo "Pushing to origin/main..."
git push origin "$BRANCH"

echo
echo "======================================"
echo "Commit and push completed successfully."
echo "======================================"
