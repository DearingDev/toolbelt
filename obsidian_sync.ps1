#requires -version 7.0

# This script syncs an Obsidian vault with a Git repository for static site generation.
# It ensures required directories exist, copies posts and images, removes stale images, and commits changes to Git.

param(
    [Parameter(Mandatory)]
    [string]$RepoPath,

    [Parameter(Mandatory)]
    [string]$VaultPath
)

function Confirm-Environment {
    Write-Host "Confirming environment..." -ForegroundColor Cyan

    try {
        # Validate the Obsidian vault path
        if (-not (Test-Path "$VaultPath\.obsidian")) {
            throw "The specified VaultPath does not appear to be an Obsidian vault (missing .obsidian directory)."
        }

        # Validate the Git repository path
        if (-not (Test-Path "$RepoPath\.git")) {
            throw "The specified RepoPath does not appear to be a Git repository (missing .git directory)."
        }

        # Check for Jekyll availability
        if (-not (Get-Command jekyll -ErrorAction SilentlyContinue)) {
            throw "Jekyll is not available in PATH."
        }

        # Ensure required directories exist in the vault
        if (-not (Test-Path "$VaultPath\posts")) {
            $createPosts = Read-Host "The 'posts' directory is missing in the vault. Do you want to create it? (y/n)"
            if ($createPosts -match '^[Yy]') {
                New-Item -ItemType Directory -Path "$VaultPath\posts" | Out-Null
                Write-Host "'posts' directory created in the vault." -ForegroundColor Green
            } else {
                throw "The 'posts' directory is required in the vault."
            }
        }

        if (-not (Test-Path "$VaultPath\assets\img")) {
            $createImages = Read-Host "The 'img' directory is missing in the vault. Do you want to create it? (y/n)"
            if ($createImages -match '^[Yy]') {
                New-Item -ItemType Directory -Path "$VaultPath\assets\img" | Out-Null
                Write-Host "'img' directory created in the vault." -ForegroundColor Green
            } else {
                throw "The 'img' directory is required in the vault."
            }
        }

        # Ensure required directories exist in the repository
        if (-not (Test-Path "$RepoPath\_posts")) {
            $createPostsRepo = Read-Host "The '_posts' directory is missing in the repository. Do you want to create it? (y/n)"
            if ($createPostsRepo -match '^[Yy]') {
                New-Item -ItemType Directory -Path "$RepoPath\_posts" | Out-Null
                Write-Host "'_posts' directory created in the repository." -ForegroundColor Green
            } else {
                throw "The '_posts' directory is required in the repository."
            }
        }

        if (-not (Test-Path "$RepoPath\assets\img")) {
            $createImagesRepo = Read-Host "The 'assets\img' directory is missing in the repository. Do you want to create it? (y/n)"
            if ($createImagesRepo -match '^[Yy]') {
                New-Item -ItemType Directory -Path "$RepoPath\assets\img" | Out-Null
                Write-Host "'assets\img' directory created in the repository." -ForegroundColor Green
            } else {
                throw "The 'assets\img' directory is required in the repository."
            }
        }
    } catch {
        Write-Error "Environment validation failed: $_"
        throw
    }
}

function Copy-ObsidianPosts {
    Write-Host "Copying posts..." -ForegroundColor Green

    try {
        $sourcePosts = Get-ChildItem -Path "$VaultPath/posts" -Filter "*.md" -ErrorAction Stop
        $repoPosts = Get-ChildItem -Path "$RepoPath/_posts" -Filter "*.md" -ErrorAction Stop

        $repoPostMap = @{}
        foreach ($post in $repoPosts) {
            $repoPostMap[$post.Name] = $post
        }

        foreach ($post in $sourcePosts) {
            try {
                # Sanitize file name to remove whitespace
                $sanitizedFileName = $post.Name -replace '\s', '-'
                if ($sanitizedFileName -ne $post.Name) {
                    $newPath = Join-Path -Path $post.DirectoryName -ChildPath $sanitizedFileName
                    Rename-Item -Path $post.FullName -NewName $sanitizedFileName -ErrorAction Stop
                    $post = Get-Item -Path $newPath -ErrorAction Stop
                    Write-Verbose "Renamed $($post.Name) to remove whitespace."
                }

                $destinationPost = Join-Path -Path $RepoPath -ChildPath ("_posts/" + $post.Name)

                if ($repoPostMap.ContainsKey($post.Name)) {
                    $repoFile = $repoPostMap[$post.Name]
                    $sourceHash = Get-FileHash -Path $post.FullName -Algorithm SHA256 -ErrorAction Stop
                    $repoHash = Get-FileHash -Path $repoFile.FullName -Algorithm SHA256 -ErrorAction Stop

                    if ($sourceHash.Hash -ne $repoHash.Hash) {
                        Write-Host "Updating $($post.Name) in the repository" -ForegroundColor Green
                        Copy-Item -Path $post.FullName -Destination $destinationPost -Force -ErrorAction Stop
                    } else {
                        Write-Verbose "$($post.Name) is up to date"
                    }
                } else {
                    Write-Host "Copying new post $($post.Name)" -ForegroundColor Green
                    Copy-Item -Path $post.FullName -Destination $destinationPost -Force -ErrorAction Stop
                }
            } catch {
                Write-Error "An error occurred while processing post $($post.Name): $_"
            }
        }

        # Handle deleted posts
        $postsInVault = $sourcePosts | ForEach-Object { $_.Name }
        foreach ($repoPost in $repoPosts) {
            try {
                if (-not ($postsInVault -contains $repoPost.Name)) {
                    $confirmDelete = Read-Host "Post $($repoPost.Name) is no longer in the vault. Do you want to delete it from the repository? (y/n)"
                    if ($confirmDelete -match '^[Yy]') {
                        Write-Host "Deleting $($repoPost.Name) from repository..." -ForegroundColor Red
                        Remove-Item -Path $repoPost.FullName -Force -ErrorAction Stop
                    }
                }
            } catch {
                Write-Error "An error occurred while deleting post $($repoPost.Name): $_"
            }
        }
    } catch {
        Write-Error "An error occurred while copying posts: $_"
        throw
    }
}

function Copy-ObsidianImages {
    Write-Host "Copying images used in posts..." -ForegroundColor Green

    try {
        $usedImages = Get-ChildItem -Path "$VaultPath\posts" -Filter "*.md" | ForEach-Object {
            Select-String -Path $_.FullName -Pattern "!\[.*\]\(assets/img/(.*?)\)" | ForEach-Object {
                $_.Matches.Groups[1].Value
            }
        }

        foreach ($encodedName in $usedImages) {
            $decodedName = [uri]::UnescapeDataString($encodedName)
            $sourceImagePath = Join-Path -Path "$VaultPath\assets\img" -ChildPath $decodedName
            $destinationImagePath = Join-Path -Path "$RepoPath\assets\img" -ChildPath $encodedName

            if (Test-Path $sourceImagePath) {
                if (-not (Test-Path $destinationImagePath)) {
                    Write-Host "Copying $encodedName to $destinationImagePath" -ForegroundColor Green
                    Copy-Item -Path $sourceImagePath -Destination $destinationImagePath -Force -ErrorAction Stop
                } else {
                    Write-Verbose "Image $encodedName already exists in the destination. Skipping copy."
                }
            } else {
                Write-Warning "Referenced image $decodedName not found in $VaultPath\assets\img"
            }
        }
    } catch {
        Write-Error "An error occurred while copying images: $_"
        throw
    }
}

function Remove-StaleImages {
    Write-Host "Removing stale images..." -ForegroundColor Yellow

    try {
        $repoImages = Get-ChildItem -Path "$RepoPath\assets\img" -Filter "*.png" -ErrorAction Stop
        $usedImages = Get-ChildItem -Path "$RepoPath\_posts" -Filter "*.md" -ErrorAction Stop | ForEach-Object {
            Select-String -Path $_.FullName -Pattern "!\[.*\]\(assets/img/(.*?)\)" -ErrorAction Stop | ForEach-Object {
                $_.Matches.Groups[1].Value
            }
        }

        foreach ($image in $repoImages) {
            try {
                if (-not ($usedImages -contains $image.Name)) {
                    Write-Host "Removing stale image: $($image.Name)" -ForegroundColor Red
                    Remove-Item -Path $image.FullName -Force -ErrorAction Stop
                }
            } catch {
                Write-Error "An error occurred while removing image $($image.Name): $_"
            }
        }
    } catch {
        Write-Error "An error occurred while processing stale images: $_"
        throw
    }
}

function Invoke-GitCommitAndPush {
    Write-Host "Committing and optionally pushing changes..." -ForegroundColor Cyan
    Push-Location $RepoPath

    try {
        git add .
        Write-Host "Staged all changes for commit." -ForegroundColor Green

        $defaultMessage = "Sync posts and images $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        $customMessage = Read-Host "Enter a custom commit message or press Enter to use the default"
        $commitMessage = if ([string]::IsNullOrWhiteSpace($customMessage)) { 
            $defaultMessage 
        } else { 
            $customMessage 
        }

        git commit -m "$commitMessage"
        Write-Host "Changes committed with message: $commitMessage" -ForegroundColor Green

        $pushConfirm = Read-Host "Do you want to push the commit to the remote repository? (y/n)"
        if ($pushConfirm -match '^[Yy]') {
            git push
            Write-Host "Changes pushed to the remote repository." -ForegroundColor Green
        } else {
            Write-Host "Push operation skipped." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "An error occurred during the Git commit or push process: $_"
    } finally {
        Pop-Location
    }
}

# MAIN
Confirm-Environment
Copy-ObsidianPosts
Copy-ObsidianImages
Remove-StaleImages
Invoke-GitCommitAndPush

Write-Host "Sync complete!" -ForegroundColor Green