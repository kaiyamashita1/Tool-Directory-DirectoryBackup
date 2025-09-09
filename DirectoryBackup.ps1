param (
    [string]$CsvFilePath,  # CSVファイルのパス
    [string]$Suffix  # Suffix
)

# CSVファイルの存在確認
if (-not (Test-Path -Path $CsvFilePath)) {
    Write-Output "指定したCSVファイルが存在しません: $CsvFilePath"
    exit
}

# CSVファイルを読み込む
$BackupEntries = Import-Csv -Path $CsvFilePath -Delimiter "," -Encoding oem

# 非同期のzip圧縮処理を格納するためのリスト
$jobs = @()

foreach ($Entry in $BackupEntries) {
    Write-Output $Entry
    $SourceFolder = $Entry."バックアップフォルダパス"
    $DestinationFolder = $Entry."保管先パス"
    $Note = $Entry."備考"

    # ソースフォルダが存在するか確認
    if (-not (Test-Path -Path $SourceFolder)) {
        Write-Output "指定したフォルダが存在しません: $SourceFolder"
        continue
    }

    # 保存先フォルダが存在しない場合、同じ階層にバックアップを作成する
    if ([string]::IsNullOrEmpty($DestinationFolder) -or (-not (Test-Path -Path $DestinationFolder))) {
        Write-Output "指定した保存先フォルダが存在しません: $DestinationFolder"
        $DestinationFolder = Split-Path -Path $SourceFolder -Parent
    }
    Write-Output $DestinationFolder

    # カレントディレクトリの絶対パスを取得
    $CurrentDir = Get-Location

    # 一時フォルダの作成（カレントディレクトリ内に作成）
    $TempFolder = Join-Path -Path $CurrentDir -ChildPath "tmp"
    if (-not (Test-Path -Path $TempFolder)) {
        New-Item -Path $TempFolder -ItemType Directory
    }

    # ソースフォルダを一時フォルダにコピー
    $TempSourceFolder = Join-Path -Path $TempFolder -ChildPath (Split-Path -Path $SourceFolder -Leaf)
    if (Test-Path -Path $TempSourceFolder) {
        Remove-Item -Path $TempSourceFolder -Recurse -Force
    }
    Copy-Item -Path $SourceFolder -Destination $TempSourceFolder -Recurse

    # ZIPファイル名の作成
    $FolderName = Split-Path -Path $SourceFolder -Leaf
    $DateTime = Get-Date -Format "yyyyMMdd_HHmm"
    $ZipFileName = "${FolderName}_${DateTime}_${Suffix}.zip"
    $ZipFilePath = Join-Path -Path $DestinationFolder -ChildPath $ZipFileName

    # 非同期で処理するジョブを作成
    $job = Start-Job -ScriptBlock {
        param ($TempSourceFolder, $ZipFilePath)
        
        try {
            # ZIP圧縮を実行
            Compress-Archive -Path $TempSourceFolder -DestinationPath $ZipFilePath -Force
            Write-Output "バックアップ作成成功: $ZipFilePath"
        } catch {
            Write-Output "エラーが発生しました: $_"
        }
        
        # 一時フォルダのクリーンアップ（圧縮後に削除）
        Remove-Item -Path $TempSourceFolder -Recurse -Force
    } -ArgumentList $TempSourceFolder, $ZipFilePath

    # ジョブをリストに追加
    $jobs += $job
}

# すべてのジョブが完了するのを待機
$jobs | ForEach-Object {
    # ジョブが完了するまで待機
    $jobResult = Wait-Job -Job $_
    # ジョブの出力結果を表示
    $jobResult | Receive-Job
    # ジョブの削除
    Remove-Job -Job $_
}

Write-Output "すべてのバックアップ処理が完了しました。"
