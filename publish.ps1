param(
    [string]$Version,
    [switch]$Major,
    [switch]$Minor,
    [switch]$Patch,
    [string]$CsprojPath,
    [string]$ProductName,
    # 软件仓库根目录（SMB 共享路径；AutoUpdater.NET 走 file:// 下载，不需要 HTTP 服务）
    # 脚本会在其下创建/使用一个与项目同名的文件夹，把更新包和 appcast.xml 都放进去
    [string]$RepositoryRoot = "\\192.168.0.150\研发部文件共享\软件组\SoftwareRepository",
    # 高级用法：显式指定更新包与 appcast.xml 的完整存放地址（UNC 或 http(s)://）
    # 一旦传入，就不再自动拼接 RepositoryRoot\项目名，脚本按原样使用
    [string]$BaseUrl = "",
    # 强制更新（appcast.xml 的 mandatory=true）
    [switch]$Mandatory,
    [string]$Runtime = "win-x64",
    [switch]$SelfContained,
    # 更新包形式（决定 AutoUpdater.NET 拿到包之后做什么）：
    #   zip —— 库用内置 ZipExtractor 自动解压覆盖安装目录并重启，全程无需人工干预（默认，最稳）
    #   exe / msi —— 库下载后只是"启动"这个文件，替换/卸载登记等由安装包自己完成，
    #             所以必须配 -InstallerPath 指定真正的安装包；裸的应用 exe 在这里不适用
    #             （便携版/只更新一个 exe，请把它放进 zip 用默认 zip 模式）
    [ValidateSet("zip", "exe", "msi")]
    [string]$PackageFormat = "zip",
    # PackageFormat 为 exe/msi 时必填：已构建好的安装包完整路径（Inno Setup、NSIS、MSI 等均可）
    [string]$InstallerPath = ""
)

$ErrorActionPreference = "Stop"

# 就地修改 appcast.xml 用：$Parent 下名为 $Name 的节点，有则改文本，无则新建
function Update-CastNode {
    param(
        [System.Xml.XmlElement]$Parent,
        [string]$Name,
        [string]$Value,
        [string]$AttrName,
        [string]$AttrValue
    )
    $node = $Parent.SelectSingleNode($Name)
    if ($null -eq $node) {
        $node = $Parent.OwnerDocument.CreateElement($Name)
        [void]$Parent.AppendChild($node)
    }
    $node.InnerText = $Value
    if ($AttrName) { $node.SetAttribute($AttrName, $AttrValue) }
}

# 自动查找主程序 csproj（当前目录，不递归）
if ([string]::IsNullOrEmpty($CsprojPath)) {
    $curDir = (Get-Location).Path
    $allFiles = Get-ChildItem -Path $curDir -File
    $csprojFiles = @()
    foreach ($f in $allFiles) {
        if ($f.Name.EndsWith(".csproj")) {
            $csprojFiles += $f
        }
    }
    if ($csprojFiles.Count -eq 0) {
        Write-Host "错误：未找到主程序 .csproj 文件，请用 -CsprojPath 指定" -ForegroundColor Red
        exit 1
    }
    # 优先选取与目录同名的 csproj（避免误选无关工程文件）
    $preferred = $csprojFiles | Where-Object { $_.BaseName -eq (Split-Path $curDir -Leaf) } | Select-Object -First 1
    if ($preferred) {
        $CsprojPath = $preferred.FullName
    } else {
        $CsprojPath = $csprojFiles[0].FullName
    }
}
$CsprojPath = [System.IO.Path]::GetFullPath($CsprojPath)
$ProjectDir = Split-Path -Parent $CsprojPath
$CsprojName = [System.IO.Path]::GetFileNameWithoutExtension($CsprojPath)

if ([string]::IsNullOrEmpty($ProductName)) {
    $ProductName = $CsprojName
}

$PublishDir = Join-Path $ProjectDir "publish"

# 软件仓库中本项目的目录：RepositoryRoot\<项目名>
if ([string]::IsNullOrEmpty($BaseUrl)) {
    $BaseUrl = Join-Path $RepositoryRoot $CsprojName
}

# 目标是文件系统路径（UNC 或本地盘）时，脚本直接把产物写进去；http(s) 只能由人工上传
$SharePath = $null
if ($BaseUrl -match '^(\\\\[^\\]+\\|[A-Za-z]:\\)') {
    $SharePath = $BaseUrl.TrimEnd('\', '/')
} elseif ($BaseUrl -match '^file://') {
    $SharePath = ([System.Uri]$BaseUrl).LocalPath.TrimEnd('\', '/')
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  $ProductName 发布脚本 (.NET 10 / V2 AutoUpdater.NET)" -ForegroundColor Cyan
Write-Host "  项目文件: $CsprojPath" -ForegroundColor Cyan
Write-Host "  运行时: $Runtime" -ForegroundColor Cyan
Write-Host "  自包含: $SelfContained" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 确定目标版本号
if (-not (Test-Path $CsprojPath)) {
    Write-Host "错误：找不到 $CsprojPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content $CsprojPath -Raw -Encoding UTF8
$currentVersion = ""
if ($content -match '<Version>([^<]+)</Version>') {
    $currentVersion = $Matches[1]
}

if (-not [string]::IsNullOrEmpty($Version)) {
    $targetVersion = $Version
    $versionSource = "手动指定"
}
else {
    if ([string]::IsNullOrEmpty($currentVersion)) {
        Write-Host "错误：.csproj 里没有找到 <Version> 配置" -ForegroundColor Red
        exit 1
    }

    $parts = $currentVersion.Split('.')
    if ($parts.Length -lt 3) {
        Write-Host "错误：当前版本号格式不正确（$currentVersion）" -ForegroundColor Red
        exit 1
    }

    $verMajor = [int]$parts[0]
    $verMinor = [int]$parts[1]
    $verPatch = [int]$parts[2]

    if ($Major) {
        $verMajor++
        $verMinor = 0
        $verPatch = 0
        $versionSource = "自动叠加主版本号"
    }
    elseif ($Minor) {
        $verMinor++
        $verPatch = 0
        $versionSource = "自动叠加次版本号"
    }
    else {
        $verPatch++
        $versionSource = "自动叠加修订号"
    }

    $targetVersion = "$verMajor.$verMinor.$verPatch"
}

if ($targetVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "错误：版本号格式不正确（$targetVersion）" -ForegroundColor Red
    exit 1
}

# ---- 更新包名/路径：按 PackageFormat 决定 ----
# zip：脚本自己把 publish 目录压成包（库会自动解压覆盖，最省事）
# exe/msi：库只会"启动"这个文件，所以必须是真的安装包，由它自己完成覆盖安装
if ($PackageFormat -eq "zip") {
    if (-not [string]::IsNullOrEmpty($InstallerPath)) {
        Write-Host "错误：-PackageFormat zip 不需要 -InstallerPath（zip 由脚本自动打包）" -ForegroundColor Red
        exit 1
    }
    $PackageName = "${ProductName}_v$targetVersion.zip"
    $PackageIsExternal = $false
} else {
    if ([string]::IsNullOrEmpty($InstallerPath)) {
        Write-Host "错误：-PackageFormat $PackageFormat 必须搭配 -InstallerPath 指定已构建好的安装包" -ForegroundColor Red
        Write-Host '  例：.\publish.ps1 -PackageFormat exe -InstallerPath "D:\ci\Setup_1.0.20.exe"' -ForegroundColor Red
        Write-Host '  说明：AutoUpdater.NET 对非 zip 包只做"下载后启动"，不会解压覆盖；' -ForegroundColor Red
        Write-Host "        直接把编译出来的应用 exe 当包发出去，装完并不会替换旧文件，等于没更新。" -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        Write-Host "错误：指定的安装包不存在：$InstallerPath" -ForegroundColor Red
        exit 1
    }
    $InstallerFullPath = [System.IO.Path]::GetFullPath($InstallerPath)
    $InstallerExt = [System.IO.Path]::GetExtension($InstallerFullPath).TrimStart('.').ToLowerInvariant()
    if ($InstallerExt -ne $PackageFormat) {
        Write-Host "错误：安装包扩展名 .$InstallerExt 与 -PackageFormat $PackageFormat 不一致" -ForegroundColor Red
        exit 1
    }

    # 关键：appcast 的 <version> 必须等于安装包里程序的版本，否则客户端装完仍认为自己落后，
    # 会无限重复弹同一个更新（或反过来永远检测不到更新）。这里强制对齐。
    $installerVer = $null
    try {
        $vi = (Get-Item -LiteralPath $InstallerFullPath).VersionInfo
        foreach ($raw in @($vi.FileVersion, $vi.ProductVersion)) {
            if ($raw) {
                $m = [System.Text.RegularExpressions.Regex]::Match($raw, '\d+\.\d+\.\d+')
                if ($m.Success) { $installerVer = $m.Value; break }
            }
        }
    } catch { }

    if ([string]::IsNullOrEmpty($Version)) {
        if (-not $installerVer) {
            Write-Host "错误：读不出安装包版本，无法确定 appcast 该写哪个版本号。" -ForegroundColor Red
            Write-Host "  请用 -Version 显式指定安装包内程序的版本号，例：-Version 1.0.20" -ForegroundColor Red
            exit 1
        }
        $targetVersion = $installerVer
        $versionSource = "取自安装包文件版本"
        Write-Host "  目标版本号改为取自安装包：v$targetVersion" -ForegroundColor Yellow
    } elseif ($installerVer -and ($installerVer -ne $targetVersion)) {
        Write-Host "错误：安装包内版本是 v$installerVer，与本次发布版本 v$targetVersion 不一致。" -ForegroundColor Red
        Write-Host "  客户端装完会发现版本没变，反复提示同一个更新。请用目标版本号重新构建安装包，" -ForegroundColor Red
        Write-Host "  或改用 -Version $installerVer 发布。" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "  安装包版本校验通过：v$targetVersion" -ForegroundColor Green
    }

    # 仓库内统一命名，避免安装包原名带空格/中文给 file:// URI 添麻烦
    $PackageName = "${ProductName}_v$targetVersion.$PackageFormat"
    $PackageIsExternal = $true
}
$PackagePath = Join-Path $ProjectDir $PackageName
$AppcastSep = if ($SharePath) { '\' } else { '/' }
$AppcastXml = $BaseUrl.TrimEnd('\', '/') + $AppcastSep + "appcast.xml"

Write-Host "当前版本: v$currentVersion" -ForegroundColor Cyan
Write-Host "目标版本: v$targetVersion ($versionSource)" -ForegroundColor Cyan

# 2. 修改 .csproj 版本号
Write-Host "`n[1/4] 修改 .csproj 版本号..." -ForegroundColor Yellow
$content = $content -replace '<Version>[^<]*</Version>', "<Version>$targetVersion</Version>"
$content = $content -replace '<FileVersion>[^<]*</FileVersion>', "<FileVersion>$targetVersion.0</FileVersion>"
$content = $content -replace '<AssemblyVersion>[^<]*</AssemblyVersion>', "<AssemblyVersion>$targetVersion.0</AssemblyVersion>"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($CsprojPath, $content, $utf8NoBom)
Write-Host "  版本号已修改为 v$targetVersion" -ForegroundColor Green

# 3. 清理旧发布目录（外部安装包模式不需要发布目录，保留原有内容不动）
if ($PackageIsExternal) {
    Write-Host "`n[2/4] 外部安装包模式，跳过清理与编译发布目录" -ForegroundColor DarkGray
} elseif (Test-Path $PublishDir) {
    Write-Host "`n[2/4] 清理旧发布目录..." -ForegroundColor Yellow
    Remove-Item $PublishDir -Recurse -Force
    Write-Host "  已清理" -ForegroundColor Green
}

# 4. 编译发布主程序
#    对比 V1：没有"编译自研 Updater 并复制"步骤——
#    AutoUpdater.NET 的 ZipExtractor.exe 以资源形式内嵌在库 DLL 中，运行时自动释放，无需单独工程。
#    用外部安装包（exe/msi）时，包是 CI/打包工具产出的，这里不需要再编译。
Write-Host "`n[3/4] 编译发布主程序..." -ForegroundColor Yellow
if ($PackageIsExternal) {
    Write-Host "  使用外部安装包，跳过编译：$InstallerFullPath" -ForegroundColor DarkGray
    $fileCount = 0
} else {
    # $selfContainedArg = if ($SelfContained) { "--self-contained:true" } else { "--self-contained:false" }
    # dotnet publish $CsprojPath -c Release -r $Runtime $selfContainedArg -o $PublishDir --nologo
    if ($FrameworkDependent) {
        dotnet publish $CsprojPath -c Release -r $Runtime --self-contained:false -o $PublishDir --nologo
    } else {
        dotnet publish $CsprojPath -c Release -r $Runtime --self-contained:true `
            -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
            -o $PublishDir --nologo
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "错误：编译发布失败" -ForegroundColor Red
        exit 1
    }
    $fileCount = (Get-ChildItem $PublishDir -Recurse -File).Count
    Write-Host "  发布完成，共 $fileCount 个文件" -ForegroundColor Green
}

# 5. 生成更新包 + 把产物发布进软件仓库（AutoUpdater.NET 的"服务器端契约"）
Write-Host "`n[4/4] 生成 $PackageFormat 更新包并发布到软件仓库..." -ForegroundColor Yellow

if ($PackageIsExternal) {
    # 外部安装包：原样复制进仓库目录名，不重新生成
    Copy-Item -LiteralPath $InstallerFullPath -Destination $PackagePath -Force
} else {
    if (Test-Path $PackagePath) { Remove-Item $PackagePath -Force }
    Compress-Archive -Path "$PublishDir\*" -DestinationPath $PackagePath -CompressionLevel Optimal
}
$packageSize = (Get-Item $PackagePath).Length / 1MB

# SHA256 校验和（AutoUpdater.NET 下载后自动比对 <checksum>）
$hash = (Get-FileHash -Path $PackagePath -Algorithm SHA256).Hash
$mandatoryValue = if ($Mandatory) { "true" } else { "false" }
$packageUrl = $BaseUrl.TrimEnd('\', '/') + "/" + $PackageName

# url 为 UNC 共享路径时转 file:// URI（AutoUpdater.NET 用 WebClient 下载，原生支持 file 方案；
# 经 System.Uri 规范化，中文段会自动百分号转义，避免下游解析歧义）
if ($packageUrl -match '^\\\\') {
    $packageUrl = ([System.Uri]$packageUrl).AbsoluteUri
}

$appcastPath = Join-Path $ProjectDir "appcast.xml"

if ($SharePath) {
    # 5a. 仓库根下确保存在与项目同名的文件夹，更新包直接复制进去
    if (-not (Test-Path -LiteralPath $SharePath)) {
        New-Item -ItemType Directory -Path $SharePath -Force | Out-Null
        Write-Host "  已创建仓库目录: $SharePath" -ForegroundColor Green
    }
    $SharePackagePath = Join-Path $SharePath $PackageName
    Copy-Item -LiteralPath $PackagePath -Destination $SharePackagePath -Force
    Write-Host "  更新包已发布: $SharePackagePath" -ForegroundColor Green

    # 5b. 自动修改仓库里的 appcast.xml：已存在则就地更新四个字段（保留其他人工节点），不存在则新建
    $shareAppcast = Join-Path $SharePath "appcast.xml"
    $doc = New-Object System.Xml.XmlDocument
    if (Test-Path -LiteralPath $shareAppcast) {
        $doc.Load($shareAppcast)
    } else {
        $doc.LoadXml('<?xml version="1.0" encoding="UTF-8"?><item></item>')
    }
    Update-CastNode -Parent $doc.DocumentElement -Name "version"   -Value "$targetVersion.0"
    Update-CastNode -Parent $doc.DocumentElement -Name "url"        -Value $packageUrl
    Update-CastNode -Parent $doc.DocumentElement -Name "mandatory"  -Value $mandatoryValue
    Update-CastNode -Parent $doc.DocumentElement -Name "checksum"   -Value $hash -AttrName "algorithm" -AttrValue "SHA256"
    $doc.Save($shareAppcast)
    Write-Host "  appcast.xml 已自动更新: $shareAppcast" -ForegroundColor Green

    # 5c. 工程本地 appcast.xml 与仓库保持同一份内容
    Copy-Item -LiteralPath $shareAppcast -Destination $appcastPath -Force
} else {
    # http(s) 源：脚本无法直接写文件，仅生成本地产物，需人工上传
    $appcastContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<item>
  <version>$targetVersion.0</version>
  <url>$packageUrl</url>
  <mandatory>$mandatoryValue</mandatory>
  <checksum algorithm="SHA256">$hash</checksum>
</item>
"@
    [System.IO.File]::WriteAllText($appcastPath, $appcastContent, $utf8NoBom)
}

Write-Host "  已生成: $PackageName ($([math]::Round($packageSize, 2)) MB)" -ForegroundColor Green
Write-Host "  已生成: appcast.xml" -ForegroundColor Green
Write-Host "  SHA256: $hash" -ForegroundColor DarkGray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  发布完成！" -ForegroundColor Green
Write-Host "  版本: v$currentVersion -> v$targetVersion" -ForegroundColor Green
Write-Host "  包形式: $PackageFormat" -ForegroundColor Green
if (-not $PackageIsExternal) {
    Write-Host "  发布目录: $PublishDir" -ForegroundColor Green
}
Write-Host "  更新包: $PackagePath" -ForegroundColor Green
if ($SharePath) {
    Write-Host "  仓库目录: $SharePath" -ForegroundColor Green
    Write-Host "  仓库更新包: $SharePackagePath" -ForegroundColor Green
    Write-Host "  仓库 AppCast: $(Join-Path $SharePath 'appcast.xml')" -ForegroundColor Green
}
Write-Host "  本地 AppCast: $appcastPath" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
if ($SharePath) {
    Write-Host "`n更新包与 appcast.xml 已自动写入软件仓库，无需手工上传。" -ForegroundColor Yellow
    Write-Host "  客户端在""更新源""里填 $AppcastXml 后点击""检查更新""即可" -ForegroundColor Yellow
    if ($PackageIsExternal) {
        Write-Host "`n注意：$PackageFormat 包由 AutoUpdater.NET 下载后直接启动，解压/覆盖不是库做的。" -ForegroundColor Yellow
        Write-Host "  安装流程（进度条、装完重启）全部依赖安装包自身，请确认它会覆盖旧版本目录。" -ForegroundColor Yellow
        Write-Host "  若只想替换几个文件，建议改用默认 zip 形式，库能全自动完成替换并重启。" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nBaseUrl 为 http(s) 地址，脚本无法直接写入，请手工把 $PackageName 和 appcast.xml 上传到：" -ForegroundColor Yellow
    Write-Host "  $BaseUrl" -ForegroundColor Yellow
    Write-Host "  客户端在""更新源""里填 $AppcastXml 后点击""检查更新""即可" -ForegroundColor Yellow
}
