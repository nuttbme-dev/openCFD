# PowerShell script to rename .STL to .stl
# Path: C:\Users\Win10Pro2024v3\Desktop\NUEJ\Coating\final\Coating\STL_Export_2026-06-15_19-39-29

$folderPath = "C:\Users\Win10Pro2024v3\Desktop\NUEJ\Coating\final\Coating\cfd_jet_test\STL_Export_2026-07-16_16-38-21"

# Check if folder exists
if (Test-Path $folderPath) {
    Write-Host "Processing folder: $folderPath" -ForegroundColor Yellow
    
    # Find all .STL files (uppercase)
    $files = Get-ChildItem -Path $folderPath -Filter "*.STL"
    
    if ($files.Count -eq 0) {
        Write-Host "No .STL files found. Checking for any STL files..." -ForegroundColor Cyan
        $files = Get-ChildItem -Path $folderPath -Filter "*.stl"
        
        if ($files.Count -gt 0) {
            Write-Host "Files are already .stl (lowercase). No rename needed." -ForegroundColor Green
        } else {
            Write-Host "No STL files found in this folder." -ForegroundColor Red
        }
    } else {
        # Rename each .STL to .stl
        foreach ($file in $files) {
            $newName = $file.FullName -replace "\.STL$", ".stl"
            Rename-Item -Path $file.FullName -NewName $newName -Force
            Write-Host "Renamed: $($file.Name) -> $([System.IO.Path]::GetFileName($newName))" -ForegroundColor Green
        }
        
        Write-Host "`nDone! Renamed $($files.Count) file(s) from .STL to .stl" -ForegroundColor Green
    }
} else {
    Write-Host "Folder not found: $folderPath" -ForegroundColor Red
}