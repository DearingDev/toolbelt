# Obsidian to Jekyll Git Sync Script

This PowerShell script automates the process of synchronizing an Obsidian vault with a Git repository configured for a Jekyll static site. It handles copying posts and images, removing outdated images, and committing the changes to your Git repository.

## Description

The script performs the following key actions:

1.  **Environment Confirmation**: Verifies that the specified Obsidian vault and Git repository paths are valid. It also checks if Jekyll is installed and accessible in your PATH. It ensures that the necessary directory structures (`posts`, `assets/img` in the vault, and `_posts`, `assets/img` in the repo) exist, prompting to create them if they are missing.
2.  **Copy Obsidian Posts**:
    * Copies Markdown files (`.md`) from the `posts` directory in your Obsidian vault to the `_posts` directory in your Git repository.
    * Sanitizes post filenames by replacing whitespace with hyphens.
    * Compares file hashes (SHA256) to only update posts that have changed.
    * Prompts for confirmation before deleting posts from the repository that no longer exist in the vault.
3.  **Copy Obsidian Images**:
    * Scans Markdown posts in the vault for image references (e.g., `![](assets/img/image-name.png)`).
    * Copies these referenced images from `VAULT_PATH/assets/img/` to `REPO_PATH/assets/img/`.
    * Handles URL-encoded image filenames, ensuring correct copying.
    * Skips copying if the image already exists in the destination.
4.  **Remove Stale Images**:
    * Identifies images in the `REPO_PATH/assets/img/` directory (currently checks for `.png` files) that are no longer referenced in any Markdown posts within the `REPO_PATH/_posts/` directory.
    * Removes these stale images to keep the repository clean.
5.  **Git Commit and Push**:
    * Stages all changes in the Git repository.
    * Prompts the user for a custom commit message or uses a default message with the current timestamp.
    * Commits the changes.
    * Asks for confirmation before pushing the commit to the remote repository.

## Prerequisites

* **PowerShell Version**: 7.0 or higher.
* **Git**: Must be installed and accessible in your system's PATH.
* **Jekyll**: Must be installed and accessible in your system's PATH if you intend to build the Jekyll site locally. The script checks for its presence.
* **Obsidian Vault Structure**:
    * A `.obsidian` directory at the root of your vault.
    * A `posts` directory for your Markdown blog posts.
    * An `assets/img` directory (relative to the vault root) for images referenced in your posts.
* **Git Repository Structure (Jekyll Standard)**:
    * A `.git` directory at the root of your repository.
    * A `_posts` directory for your Markdown blog posts.
    * An `assets/img` directory (relative to the repository root) for images.

## Usage

Run the script from a PowerShell terminal, providing the paths to your Obsidian vault and your Git repository.

```powershell
.\obsidian_sync.ps1 -RepoPath "C:\path\to\your\site\repo" -VaultPath "C:\path\to\your\obsidian-vault"