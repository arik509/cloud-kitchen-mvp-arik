$files = @(
    'supabase/migrations/20260813200213_kitchen_order_status.sql',
    'supabase/migrations/20260728122000_place_order.sql',
    'supabase/migrations/20260813181738_my_kitchen_images_and_status.sql'
)
foreach ($f in $files) {
    $content = Get-Content $f -Raw
    $lf = $content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText((Resolve-Path $f), $lf)
    Write-Host "Normalized: $f"
}
