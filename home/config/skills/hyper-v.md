---
name: hyper-v
description: Hyper-V Management and VM Orchestration from WSL2. Use when Gemini CLI needs to create, configure, or interact with virtual machines on the Windows host.
---

# Hyper-V Management Skill

This skill allows Gemini CLI to manage Hyper-V virtual machines and their resources directly from the WSL2 environment using the Windows PowerShell bridge.

## Core Directives

* **PowerShell Bridge**: ALWAYS prefix Hyper-V commands with `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -Command`.
* **Output Handling**: Always pipe PowerShell output through `tr -d '\r'` to remove Windows carriage returns when capturing output into variables.
* **Path Mapping**: When referring to paths on the Windows host, use Windows-style paths (e.g., `C:\VMs\disk.vhdx`). For files created in WSL, use `/mnt/c/...` paths.
* **Permissions**: Assume the user has administrative privileges on the Windows host, as Hyper-V management typically requires it.

## Common Workflows

### 1. Creating a VM
```bash
powershell.exe -Command "New-VM -Name '$VM_NAME' -MemoryStartupBytes $RAM_BYTES -Generation 2 -NewVHDPath '$VHD_PATH' -NewVHDSizeBytes $VHD_SIZE_BYTES"
```
*Note: Default to Generation 2 VMs for modern operating systems like NixOS.*

### 2. Configuring VM Settings
```bash
powershell.exe -Command "Set-VM -Name '$VM_NAME' -ProcessorCount 4 -DynamicMemoryEnabled $true"
```

### 3. Disk & Partition Management
To initialize and partition a disk within a VM or a mounted VHD:
```bash
# Initialize and partition a new disk
powershell.exe -Command "Initialize-Disk -Number $DISK_NUM -PartitionStyle GPT; New-Partition -DiskNumber $DISK_NUM -UseMaximumSize -AssignDriveLetter; Format-Volume -DriveLetter $DRIVE_LETTER -FileSystem NTFS"
```

### 4. Console Interaction (Serial Port)
To enable and interact with a serial console (e.g., for NixOS boot logs):
1. **Map Serial Port to Named Pipe**:
   ```bash
   powershell.exe -Command "Set-VMSerialPort -VMName '$VM_NAME' -Number 1 -PipeName '$VM_NAME'"
   ```
2. **Interact with Console**: Use a PowerShell script bridge to talk to the named pipe. 
   **Peek at Console Output**:
   ```powershell
   # Write this to a temp .ps1 and execute via powershell.exe
   $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', '$VM_NAME', [System.IO.Pipes.PipeDirection]::InOut)
   $pipe.Connect(2000)
   $reader = New-Object System.IO.StreamReader($pipe)
   Start-Sleep -Milliseconds 500
   while ($reader.Peek() -ne -1) { Write-Host -NoNewline ([char]$reader.Read()) }
   $pipe.Close()
   ```

## Command Reference Matrix

| Action | PowerShell Cmdlet | Description |
| :--- | :--- | :--- |
| **List VMs** | `Get-VM` | Shows name, state, and status of all VMs. |
| **Start VM** | `Start-VM -Name $Name` | Boots the virtual machine. |
| **Stop VM** | `Stop-VM -Name $Name` | Shuts down or turns off the VM. |
| **Snapshots** | `Checkpoint-VM -Name $Name` | Creates a VM checkpoint. |
| **Network** | `Get-VMSwitch` | Lists available virtual switches. |

## Interaction Protocol

* **Research First**: Before creating a VM, run `Get-VM` to ensure the name isn't taken.
* **Storage Verification**: Check available disk space on the target Windows drive before creating large VHDX files.
* **Step-by-Step**: For complex provisioning, perform operations in order: Network -> VM -> Storage -> Boot.
* **Cleanup**: Offer to remove temporary VHDs or checkpoints if they are no longer needed.
