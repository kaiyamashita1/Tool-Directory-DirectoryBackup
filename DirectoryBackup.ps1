param (
    [string]$CsvFilePath,  # CSV�t�@�C���̃p�X
    [string]$Suffix  # Suffix
)

# CSV�t�@�C���̑��݊m�F
if (-not (Test-Path -Path $CsvFilePath)) {
    Write-Output "�w�肵��CSV�t�@�C�������݂��܂���: $CsvFilePath"
    exit
}

# CSV�t�@�C����ǂݍ���
$BackupEntries = Import-Csv -Path $CsvFilePath -Delimiter "," -Encoding oem

# �񓯊���zip���k�������i�[���邽�߂̃��X�g
$jobs = @()

foreach ($Entry in $BackupEntries) {
    Write-Output $Entry
    $SourceFolder = $Entry."�o�b�N�A�b�v�t�H���_�p�X"
    $DestinationFolder = $Entry."�ۊǐ�p�X"
    $Note = $Entry."���l"

    # �\�[�X�t�H���_�����݂��邩�m�F
    if (-not (Test-Path -Path $SourceFolder)) {
        Write-Output "�w�肵���t�H���_�����݂��܂���: $SourceFolder"
        continue
    }

    # �ۑ���t�H���_�����݂��Ȃ��ꍇ�A�����K�w�Ƀo�b�N�A�b�v���쐬����
    if ([string]::IsNullOrEmpty($DestinationFolder) -or (-not (Test-Path -Path $DestinationFolder))) {
        Write-Output "�w�肵���ۑ���t�H���_�����݂��܂���: $DestinationFolder"
        $DestinationFolder = Split-Path -Path $SourceFolder -Parent
    }
    Write-Output $DestinationFolder

    # �J�����g�f�B���N�g���̐�΃p�X���擾
    $CurrentDir = Get-Location

    # �ꎞ�t�H���_�̍쐬�i�J�����g�f�B���N�g�����ɍ쐬�j
    $TempFolder = Join-Path -Path $CurrentDir -ChildPath "tmp"
    if (-not (Test-Path -Path $TempFolder)) {
        New-Item -Path $TempFolder -ItemType Directory
    }

    # �\�[�X�t�H���_���ꎞ�t�H���_�ɃR�s�[
    $TempSourceFolder = Join-Path -Path $TempFolder -ChildPath (Split-Path -Path $SourceFolder -Leaf)
    if (Test-Path -Path $TempSourceFolder) {
        Remove-Item -Path $TempSourceFolder -Recurse -Force
    }
    Copy-Item -Path $SourceFolder -Destination $TempSourceFolder -Recurse

    # ZIP�t�@�C�����̍쐬
    $FolderName = Split-Path -Path $SourceFolder -Leaf
    $DateTime = Get-Date -Format "yyyyMMdd_HHmm"
    $ZipFileName = "${FolderName}_${DateTime}_${Suffix}.zip"
    $ZipFilePath = Join-Path -Path $DestinationFolder -ChildPath $ZipFileName

    # �񓯊��ŏ�������W���u���쐬
    $job = Start-Job -ScriptBlock {
        param ($TempSourceFolder, $ZipFilePath)
        
        try {
            # ZIP���k�����s
            Compress-Archive -Path $TempSourceFolder -DestinationPath $ZipFilePath -Force
            Write-Output "�o�b�N�A�b�v�쐬����: $ZipFilePath"
        } catch {
            Write-Output "�G���[���������܂���: $_"
        }
        
        # �ꎞ�t�H���_�̃N���[���A�b�v�i���k��ɍ폜�j
        Remove-Item -Path $TempSourceFolder -Recurse -Force
    } -ArgumentList $TempSourceFolder, $ZipFilePath

    # �W���u�����X�g�ɒǉ�
    $jobs += $job
}

# ���ׂẴW���u����������̂�ҋ@
$jobs | ForEach-Object {
    # �W���u����������܂őҋ@
    $jobResult = Wait-Job -Job $_
    # �W���u�̏o�͌��ʂ�\��
    $jobResult | Receive-Job
    # �W���u�̍폜
    Remove-Job -Job $_
}

Write-Output "���ׂẴo�b�N�A�b�v�������������܂����B"
