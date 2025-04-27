# Paths are defined for my local setup. Adjust them as needed.

# Define paths
$repoPath = "C:\gitrepos\dearingdev.github.io"
$sourcePath = "C:\gitrepos\blog_tools\dearingdev\posts"
$destinationPath = "C:\gitrepos\dearingdev.github.io\_posts"
$imageSourcePath = "C:\gitrepos\blog_tools\dearingdev\images"
$imageDestinationPath = "C:\gitrepos\dearingdev.github.io\assets\images"

# Check and create destination directories if they don't exist
foreach ($path in @($destinationPath, $imageDestinationPath)) {
    if (-not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

# --- Sync Markdown Files ---

# Get list of source and destination markdown files (only filenames)
$sourceMarkdownFiles = Get-ChildItem -Path $sourcePath -Filter "*.md" | Select-Object -ExpandProperty Name
$destinationMarkdownFiles = Get-ChildItem -Path $destinationPath -Filter "*.md" | Select-Object -ExpandProperty Name

# Delete markdown files that are no longer in source
$filesToDelete = $destinationMarkdownFiles | Where-Object { $_ -notin $sourceMarkdownFiles }
foreach ($file in $filesToDelete) {
    $fullPath = Join-Path $destinationPath $file
    Write-Host "Deleting markdown file: $fullPath"
    Remove-Item -Path $fullPath -Force
}

# Copy or update markdown files
foreach ($file in $sourceMarkdownFiles) {
    Copy-Item -Path (Join-Path $sourcePath $file) -Destination $destinationPath -Force
}

# --- Process Each Markdown File to Handle Images ---

# Track which images are referenced across all posts
$referencedImages = @{}

Get-ChildItem -Path $destinationPath -Filter "*.md" | ForEach-Object {
    $markdownFilePath = $_.FullName
    Write-Host "Processing markdown file: $markdownFilePath"

    # Read markdown content
    $content = Get-Content -Path $markdownFilePath -Raw

    # Find all image references [[image name]]
    $imageNames = [regex]::Matches($content, '\[\[(.*?)\]\]').ForEach({ $_.Groups[1].Value })

    if ($imageNames.Count -eq 0) {
        Write-Host "No image links found in this file."
    } else {
        foreach ($imageName in $imageNames) {
            Write-Host "Image: $imageName"

            # Create new image filename (no spaces)
            $newImageName = $imageName -replace '\s', ''
            $sourceImagePath = Join-Path -Path $imageSourcePath -ChildPath $imageName
            $destinationImagePath = Join-Path -Path $imageDestinationPath -ChildPath $newImageName

            # Keep track of images that should exist
            $referencedImages[$newImageName] = $true

            # Copy image if needed
            if (Test-Path -Path $sourceImagePath) {
                Write-Host "Copying image from $sourceImagePath to $destinationImagePath"
                Copy-Item -Path $sourceImagePath -Destination $destinationImagePath -Force
            } else {
                Write-Host "Image not found at $sourceImagePath"
                continue
            }

            # Update the markdown content (only if needed)
            $content = $content -replace "\[\[$imageName\]\]", "[img](assets/images/$newImageName)"
        }

        # Save updated markdown content
        Set-Content -Path $markdownFilePath -Value $content
    }
}

# --- Clean Up Unused Images ---

# Get current images in the destination
$currentImages = Get-ChildItem -Path $imageDestinationPath | Select-Object -ExpandProperty Name

# Find images that are not referenced
$imagesToDelete = $currentImages | Where-Object { $_ -notin $referencedImages.Keys }
foreach ($image in $imagesToDelete) {
    $fullPath = Join-Path $imageDestinationPath $image
    Write-Host "Deleting unused image: $fullPath"
    Remove-Item -Path $fullPath -Force
}

# --- Build Jekyll Site ---

Write-Host "Building Jekyll site..."

Push-Location $repoPath

# Build the site using Jekyll
$jekyllBuildResult = & bundle exec jekyll build

if ($LASTEXITCODE -ne 0) {
    Write-Host "Jekyll build failed. Aborting git actions." -ForegroundColor Red
    Pop-Location
    exit 1
} else {
    Write-Host "Jekyll build succeeded." -ForegroundColor Green
}

# If the build was successful, you can run bundle exec jekyll serve to preview the site locally

# --- Git Actions ---

Write-Host "Staging all changes for git..."
& git add .

# Prepare commit message
$defaultMessage = "Sync posts and images $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host "Default commit message: '$defaultMessage'"
$customMessage = Read-Host "Enter a custom commit message or press Enter to use the default"

if ([string]::IsNullOrWhiteSpace($customMessage)) {
    $commitMessage = $defaultMessage
} else {
    $commitMessage = $customMessage
}

# Commit the changes
Write-Host "Committing changes..."
& git commit -m $commitMessage

# Ask if the user wants to push
$pushConfirm = Read-Host "Do you want to push the commit to the remote repository? (y/n)"

if ($pushConfirm -match '^[Yy]') {
    Write-Host "Pushing to remote..."
    & git push
    Write-Host "Changes pushed successfully."
} else {
    Write-Host "Push skipped. You can manually push later with 'git push'."
}

Pop-Location

Write-Host "Sync, build, git commit (and optional push) completed."
