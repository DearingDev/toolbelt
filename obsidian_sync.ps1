#requires -version 7.0

# Future iterations will utilize the Spectre.Console module for a more interactive experience.
#using module PwshSpectreConsole

param(
    [Parameter(Mandatory)]
    [string]$RepoPath,

    [Parameter(Mandatory)]
    [string]$VaultPath
)

function Confirm-Environment {
    Write-Host "Confirming environment..." -ForegroundColor Cyan

    if (-not (Test-Path "$VaultPath\.obsidian")) {
        throw "The specified VaultPath does not appear to be an Obsidian vault (missing .obsidian directory)."
    }

    if (-not (Test-Path "$RepoPath\.git")) {
        throw "The specified RepoPath does not appear to be a Git repository (missing .git directory)."
    }

    if (-not (Get-Command jekyll -ErrorAction SilentlyContinue)) {
        throw "Jekyll is not available in PATH."
    }

    # Check for "posts" and "img" directories in the vault
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

    # Check for "_posts" and "assets/img" directories in the repository
    if (-not (Test-Path "$RepoPath\_posts")) {
        $createPostsRepo = Read-Host "The '_posts' directory is missing in the repository. This may not be a valid static site repository. Are you sure you want to create the directory? (y/n)"
        if ($createPostsRepo -match '^[Yy]') {
            New-Item -ItemType Directory -Path "$RepoPath\_posts" | Out-Null
            Write-Host "'_posts' directory created in the repository." -ForegroundColor Green
        } else {
            throw "The '_posts' directory is required in the repository."
        }
    }

    if (-not (Test-Path "$RepoPath\assets\img")) {
        $createImagesRepo = Read-Host "The 'assets\img' directory is missing in the repository. This may not be a valid static site repository. Do you want to create it? (y/n)"
        if ($createImagesRepo -match '^[Yy]') {
            New-Item -ItemType Directory -Path "$RepoPath\assets\img" | Out-Null
            Write-Host "'assets\img' directory created in the repository." -ForegroundColor Green
        } else {
            throw "The 'assets\img' directory is required in the repository."
        }
    }
}

function Copy-ObsidianPosts {
    Write-Host "Copying posts..." -ForegroundColor Green

    $sourcePosts = Get-ChildItem -Path "$VaultPath/posts" -Filter "*.md"
    $repoPosts = Get-ChildItem -Path "$RepoPath/_posts" -Filter "*.md"

    $repoPostMap = @{}
    foreach ($post in $repoPosts) {
        $repoPostMap[$post.Name] = $post
    }

    foreach ($post in $sourcePosts) {
        # Ensure no whitespace in the file name
        $sanitizedFileName = $post.Name -replace '\s', '-'
        if ($sanitizedFileName -ne $post.Name) {
            $newPath = Join-Path -Path $post.DirectoryName -ChildPath $sanitizedFileName
            Rename-Item -Path $post.FullName -NewName $sanitizedFileName
            $post = Get-Item -Path $newPath
            Write-Host "Renamed $($post.Name) to remove whitespace." -ForegroundColor Yellow
        }

        $destinationPost = Join-Path -Path $RepoPath -ChildPath ("_posts/" + $post.Name)

        $isPostInRepo = $repoPostMap.ContainsKey($post.Name)
        if ($isPostInRepo) {
            $repoFile = $repoPostMap[$post.Name]
            $sourceHash = Get-FileHash -Path $post.FullName -Algorithm SHA256
            $repoHash = Get-FileHash -Path $repoFile.FullName -Algorithm SHA256

            if ($sourceHash.Hash -ne $repoHash.Hash) {
                Write-Host "Updating $($post.Name) in the repository" -ForegroundColor Green
                Copy-Item -Path $post.FullName -Destination $destinationPost -Force
            } else {
                Write-Host "$($post.Name) is up to date" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Copying new post $($post.Name)" -ForegroundColor Green
            Copy-Item -Path $post.FullName -Destination $destinationPost -Force
        }
    }

    # Check for deleted posts
    $postsInVault = $sourcePosts | ForEach-Object { $_.Name }
    foreach ($repoPost in $repoPosts) {
        if (-not ($postsInVault -contains $repoPost.Name)) {
            $confirmDelete = Read-Host "Post $($repoPost.Name) is no longer in the vault. Do you want to delete it from the repository? (y/n)"
            if ($confirmDelete -match '^[Yy]') {
                Write-Host "Deleting $($repoPost.Name) from repository..." -ForegroundColor Red
                Remove-Item -Path $repoPost.FullName -Force
            }
        }
    }
}

function Copy-ObsidianImages {
    Write-Host "Copying images used in posts..." -ForegroundColor Green

    # Get list of images referenced in markdown files
    $usedImages = Get-ChildItem -Path "$VaultPath\posts" -Filter "*.md" | ForEach-Object {
        Select-String -Path $_.FullName -Pattern "!\[.*\]\(\.\./assets/img/(.*?)\)" | ForEach-Object {
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
                Copy-Item -Path $sourceImagePath -Destination $destinationImagePath -Force
            } else {
                Write-Host "Image $encodedName already exists in the destination. Skipping copy." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Referenced image $decodedName not found in $VaultPath\assets\img" -ForegroundColor Yellow
        }
    }
}

function Remove-StaleImages {
    Write-Host "Removing stale images..." -ForegroundColor Yellow

    # Get list of images in the repo
    $repoImages = Get-ChildItem -Path "$RepoPath\assets\img" -Filter "*.png"
    
    # Get list of images used in posts
    $usedImages = Get-ChildItem -Path "$RepoPath\_posts" -Filter "*.md" | ForEach-Object {
        Select-String -Path $_.FullName -Pattern "!\[.*\]\(\.\./assets/img/(.*?)\)" | ForEach-Object {
            $_.Matches.Groups[1].Value
        }
    }

    # Remove stale images
    foreach ($image in $repoImages) {
        if (-not ($usedImages -contains $image.Name)) {
            Write-Host "Removing stale image: $($image.Name)" -ForegroundColor Red
            Remove-Item -Path $image.FullName -Force
        }
    }
}

function Invoke-GitCommitAndPush {
    Write-Host "Committing and optionally pushing changes..." -ForegroundColor Cyan
    Push-Location $RepoPath
    
    git add .

    $defaultMessage = "Sync posts and images $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Write-Host "Default commit message: $defaultMessage" -ForegroundColor Yellow
    $customMessage = Read-Host "Enter a custom commit message or press Enter to use the default"
    
    $commitMessage = if ([string]::IsNullOrWhiteSpace($customMessage)) { $defaultMessage } else { $customMessage }

    git commit -m "$commitMessage"

    $pushConfirm = Read-Host "Do you want to push the commit to the remote repository? (y/n)"
    if ($pushConfirm -match '^[Yy]') {
        git push
    }
    Pop-Location
}

# MAIN
Confirm-Environment

$progress = [System.Collections.Generic.List[string]]@(
    'Copy posts',
    'Copy images',
    'Remove stale images',
    'Commit and push changes'
)

$progressCount = 0
$totalSteps = $progress.Count

$progress | ForEach-Object {
    $progressCount++
    $percentComplete = ($progressCount / $totalSteps) * 100
    
    Write-Progress -Activity "Syncing blog content..." -Status $_ -PercentComplete $percentComplete

    switch ($_) {
        'Copy posts' { Copy-ObsidianPosts }
        'Copy images' { Copy-ObsidianImages }
        'Remove stale images' { Remove-StaleImages }
        'Commit and push changes' { Invoke-GitCommitAndPush }
    }
}

Write-Host "Sync complete!" -ForegroundColor Green