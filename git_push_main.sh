#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="/home/nuttbme/Documents/git/openCFD"
BRANCH="main"

cd "$REPO_DIR"

echo "======================================"
echo "Git Commit and Push to main"
echo "======================================"
echo

# Confirm this is a Git repository
if [[ ! -d ".git" ]]; then
    echo "ERROR: This directory is not a Git repository:"
    echo "$REPO_DIR"
    exit 1
fi

# Show current branch
CURRENT_BRANCH="$(git branch --show-current)"

echo "Current branch: $CURRENT_BRANCH"

if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
    echo "Switching to branch: $BRANCH"
    git switch "$BRANCH"
fi

echo
echo "Checking remote updates..."
git pull --rebase origin "$BRANCH"

echo
echo "Changed files:"
git status --short

if [[ -z "$(git status --porcelain)" ]]; then
    echo
    echo "Nothing to commit."
    exit 0
fi

echo
read -r -p "Enter commit message: " COMMIT_MESSAGE

if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo "ERROR: Commit message cannot be empty."
    exit 1
fi

echo
read -r -p "Add all changed files? [y/N]: " CONFIRM_ADD

if [[ ! "$CONFIRM_ADD" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

git add --all

echo
echo "Files staged for commit:"
git status --short

echo
read -r -p "Commit and push to main? [y/N]: " CONFIRM_PUSH

if [[ ! "$CONFIRM_PUSH" =~ ^[Yy]$ ]]; then
    echo "Cancelled before commit."
    exit 0
fi

git commit -m "$COMMIT_MESSAGE"

echo
echo "Pushing to origin/main..."
git push origin "$BRANCH"

echo
echo "======================================"
echo "Commit and push completed successfully."
echo "======================================"
