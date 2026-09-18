<#
    Перекодування аудіо мисливських сигналів.

    Навіщо: файли лежать у Drive як 320 kbps stereo 44.1 kHz. Сигнал рога —
    один духовий інструмент, монофонічний; стерео там нема чого передавати, а
    320 kbps — бітрейт для оркестрової музики. 96 kbps mono на слух не
    відрізнити, а розмір падає приблизно вп'ятеро. На повільному з'єднанні це
    різниця між 17 секундами очікування і трьома.

    Що робить: бере список сигналів із Firestore, завантажує кожен файл із
    Drive, перекодує, кладе поруч оригінал і результат, і пише mapping.csv —
    за ним видно, який вихідний файл яким Drive-файлом замінювати.

    Оригінали не чіпаються: скрипт нічого не вивантажує назад.

    Приклад:
        .\reencode_audio.ps1
        .\reencode_audio.ps1 -Bitrate 64
        .\reencode_audio.ps1 -OutDir D:\temp\signals
#>

[CmdletBinding()]
param(
    # Куди складати результат. За замовчуванням — тека reencoded поруч зі скриптом.
    [string]$OutDir = (Join-Path $PSScriptRoot 'reencoded'),

    # Цільовий бітрейт у kbps. 96 — безпечний вибір для рога; 64 теж
    # здебільшого прийнятний, 128 — якщо чутно різницю.
    [ValidateRange(32, 320)]
    [int]$Bitrate = 96,

    # Публічний веб-ключ Firebase — той самий, що вже лежить у main.dart.js.
    [string]$ApiKey = 'AIzaSyAhVTO38rw3oN0zxgH5_kXGl8Ex6mWPoPE',

    [string]$ProjectId = 'huntingsignals'
)

$ErrorActionPreference = 'Stop'

# ── ffmpeg ────────────────────────────────────────────────────────────────────
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Host ''
    Write-Host '  ffmpeg не знайдено в PATH.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Встановити одним із способів:'
    Write-Host '    winget install Gyan.FFmpeg'
    Write-Host '    choco install ffmpeg'
    Write-Host '    або завантажити з https://www.gyan.dev/ffmpeg/builds/ і додати bin у PATH'
    Write-Host ''
    Write-Host '  Після встановлення відкрий нове вікно терміналу — PATH оновлюється лише в нових.'
    Write-Host ''
    exit 1
}
Write-Host "  ffmpeg: $($ffmpeg.Source)" -ForegroundColor DarkGray

# ── Теки ──────────────────────────────────────────────────────────────────────
$originalsDir = Join-Path $OutDir 'originals'
$null = New-Item -ItemType Directory -Path $OutDir -Force
$null = New-Item -ItemType Directory -Path $originalsDir -Force

# ── Список сигналів із Firestore ──────────────────────────────────────────────
Write-Host '  Читаю список сигналів...' -ForegroundColor DarkGray

$documents = @()
$pageToken = $null
do {
    $url = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/signals?pageSize=100&key=$ApiKey"
    if ($pageToken) { $url += "&pageToken=$pageToken" }
    $page = Invoke-RestMethod -Uri $url -TimeoutSec 60
    $documents += $page.documents
    $pageToken = $page.nextPageToken
} while ($pageToken)

$signals = $documents | Where-Object { $_.fields.audioUrl.stringValue }
Write-Host ("  Сигналів з аудіо: {0}" -f ($signals | Measure-Object).Count) -ForegroundColor DarkGray
Write-Host ''

# ── Допоміжні ─────────────────────────────────────────────────────────────────
function Get-DriveId {
    param([string]$Url)
    if ($Url -match '/file/d/([^/?]+)')                    { return $matches[1] }
    if ($Url -match 'lh3\.googleusercontent\.com/d/([^/?]+)') { return $matches[1] }
    if ($Url -match '[?&]id=([^&]+)')                      { return $matches[1] }
    return $null
}

function Get-SafeName {
    param([string]$Name)
    $safe = $Name.Trim()
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace($ch, '_')
    }
    $safe = $safe -replace '\s+', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'signal' }
    return $safe
}

# ── Обробка ───────────────────────────────────────────────────────────────────
$report = @()
$index = 0

foreach ($doc in $signals) {
    $index++
    $name = $doc.fields.name.stringValue
    $audioUrl = $doc.fields.audioUrl.stringValue
    $driveId = Get-DriveId -Url $audioUrl

    $label = '{0:d2}. {1}' -f $index, $name
    Write-Host $label -ForegroundColor White

    if (-not $driveId) {
        Write-Host '      з посилання не вдалось витягти id Drive — пропускаю' -ForegroundColor Yellow
        $report += [PSCustomObject]@{
            N = $index; Name = $name; DriveId = ''; File = ''
            BeforeKB = 0; AfterKB = 0; Ratio = ''; Status = 'немає id'
        }
        continue
    }

    $safeName = Get-SafeName -Name $name
    $srcPath = Join-Path $originalsDir ('{0:d2}_{1}.mp3' -f $index, $safeName)
    $dstPath = Join-Path $OutDir      ('{0:d2}_{1}.mp3' -f $index, $safeName)

    # Завантаження. Drive віддає файл анонімно, якщо запит без кукі Google —
    # Invoke-WebRequest їх не надсилає, тож тут усе гаразд. У браузері той самий
    # запит повернув би 403, через що застосунок і ходить через власний проксі.
    try {
        $downloadUrl = "https://drive.usercontent.google.com/download?id=$driveId&export=download&authuser=0&confirm=t"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $srcPath -TimeoutSec 600 -UseBasicParsing
    }
    catch {
        Write-Host ("      не вдалось завантажити: {0}" -f $_.Exception.Message) -ForegroundColor Red
        $report += [PSCustomObject]@{
            N = $index; Name = $name; DriveId = $driveId; File = ''
            BeforeKB = 0; AfterKB = 0; Ratio = ''; Status = 'помилка завантаження'
        }
        continue
    }

    $beforeKB = [math]::Round((Get-Item $srcPath).Length / 1KB, 1)

    # Перекодування. -ac 1 зводить у моно, -b:a задає бітрейт,
    # -map_metadata -1 прибирає теги й обкладинки, які інколи важать більше
    # за сам звук. -y перезаписує, якщо файл лишився з попереднього запуску.
    & ffmpeg -hide_banner -loglevel error -y `
        -i $srcPath `
        -codec:a libmp3lame -b:a "${Bitrate}k" -ac 1 -ar 44100 `
        -map_metadata -1 `
        $dstPath

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dstPath)) {
        Write-Host '      ffmpeg завершився з помилкою' -ForegroundColor Red
        $report += [PSCustomObject]@{
            N = $index; Name = $name; DriveId = $driveId; File = ''
            BeforeKB = $beforeKB; AfterKB = 0; Ratio = ''; Status = 'помилка ffmpeg'
        }
        continue
    }

    $afterKB = [math]::Round((Get-Item $dstPath).Length / 1KB, 1)
    $ratio = if ($afterKB -gt 0) { [math]::Round($beforeKB / $afterKB, 1) } else { 0 }

    Write-Host ("      {0} КБ -> {1} КБ  (менше у {2} рази)" -f $beforeKB, $afterKB, $ratio) -ForegroundColor Green

    $report += [PSCustomObject]@{
        N = $index
        Name = $name
        DriveId = $driveId
        File = Split-Path $dstPath -Leaf
        BeforeKB = $beforeKB
        AfterKB = $afterKB
        Ratio = "${ratio}x"
        Status = 'готово'
    }
}

# ── Підсумок ──────────────────────────────────────────────────────────────────
Write-Host ''
$report | Format-Table N, Name, BeforeKB, AfterKB, Ratio, Status -AutoSize

$done = $report | Where-Object { $_.Status -eq 'готово' }
$sumBefore = ($done | Measure-Object BeforeKB -Sum).Sum
$sumAfter = ($done | Measure-Object AfterKB -Sum).Sum

if ($sumAfter -gt 0) {
    Write-Host ("  Разом: {0} МБ -> {1} МБ  (менше у {2} рази)" -f `
        [math]::Round($sumBefore / 1024, 2),
        [math]::Round($sumAfter / 1024, 2),
        [math]::Round($sumBefore / $sumAfter, 1)) -ForegroundColor Cyan
}

$mappingPath = Join-Path $OutDir 'mapping.csv'
$report | Export-Csv -Path $mappingPath -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host '  Результат:' -ForegroundColor White
Write-Host "    перекодовані: $OutDir"
Write-Host "    оригінали:    $originalsDir"
Write-Host "    відповідність Drive: $mappingPath"
Write-Host ''
Write-Host '  Далі:' -ForegroundColor White
Write-Host '    1. Послухай пару файлів поруч з оригіналами. Якщо чутно різницю —'
Write-Host '       перезапусти з -Bitrate 128.'
Write-Host '    2. У Drive для кожного файлу: правий клік -> Керування версіями ->'
Write-Host '       Завантажити нову версію. Id файлу при цьому НЕ змінюється,'
Write-Host '       тож ані Firestore, ані код правити не треба.'
Write-Host '    3. Кеш Vercel тримає стару версію за тим самим id до року.'
Write-Host '       Після заміни його треба скинути: vercel deploy --prod --force'
Write-Host ''
