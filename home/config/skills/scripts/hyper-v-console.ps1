param (
    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$false)]
    [string]$Command,

    [Parameter(Mandatory=$false)]
    [int]$ReadTimeout = 2000,

    [Parameter(Mandatory=$false)]
    [switch]$Peek
)

$PipeName = $VMName # Assuming PipeName matches VMName as per our skill convention
$pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $PipeName, [System.IO.Pipes.PipeDirection]::InOut)

try {
    $pipe.Connect(2000)
} catch {
    Write-Error "Could not connect to pipe \\.\pipe\$PipeName. Ensure VM is running and Serial Port 1 is configured with this PipeName."
    exit 1
}

$writer = New-Object System.IO.StreamWriter($pipe)
$reader = New-Object System.IO.StreamReader($pipe)
$writer.AutoFlush = $true

if ($Command) {
    $writer.WriteLine($Command)
}

if ($Peek -or -not $Command) {
    # Read what's currently in the buffer
    $startTime = Get-Date
    while ($pipe.IsConnected -and ((Get-Date) - $startTime).TotalMilliseconds -lt $ReadTimeout) {
        if ($null -ne $reader.Peek() -and $reader.Peek() -ne -1) {
            Write-Host -NoNewline ([char]$reader.Read())
        } else {
            Start-Sleep -Milliseconds 100
        }
    }
}

$pipe.Close()
