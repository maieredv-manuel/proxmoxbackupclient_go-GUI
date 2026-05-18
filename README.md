# proxmoxbackupclient_go-GUI

A lightweight PowerShell-based Graphical User Interface for the [proxmox-backup-client-go](https://github.com/tizbac/proxmoxbackupclient_go) by tizbac. This tool simplifies managing directory and physical drive backups to a Proxmox Backup Server (PBS) from Windows machines.

## Features

- **Dual Mode Backup:** Supports both `pbsdirectorybackup.exe` (for folders) and `pbsmachinebackup.exe` (for physical disk images).
- **Automated Scheduling:** Easily register backup jobs in the Windows Task Scheduler to run under the `SYSTEM` account.
- **Auto-Elevation:** Automatically requests Administrator privileges required for VSS snapshots and disk access.
- **Physical Drive Mapping:** Automatically detects and correctly formats physical drive paths (e.g., `\\.\PhysicalDrive0`) to avoid common CLI syntax errors.
- **Job Management:** Save, edit, and delete multiple backup configurations in a local `backup_jobs.json` file.
- **Global Email Configuration:** Configure SMTP settings once and apply them seamlessly to all backup jobs for status notifications.

## Prerequisites

1. Download the latest Windows release of `proxmox-backup-client-go` from [tizbac's repository](https://github.com/tizbac/proxmoxbackupclient_go/releases).
2. Extract the executables (`pbsdirectorybackup.exe` and `pbsmachinebackup.exe`) into the same folder as this script.

## Setup & Usage

1. Place `proxmoxclient_go_gui.ps1` in the directory containing the PBS executables.
2. Right-click the script and select **Run with PowerShell**.
3. Fill in your PBS details (URL, Fingerprint, Token, Secret).
4. Select **Directory** or **Machine** mode and choose your source.
5. Click **Save Job**, then either **RUN JOB NOW** to test or check **Enable scheduled backup** for recurring tasks.

## Known Issues / Limitations

- **VM Backup Mode (`-type vm`):** Checking the "Mark as VM" option in the GUI currently causes upload errors on the Proxmox Backup Server. This is due to a known bug / incomplete implementation in the underlying `pbsmachinebackup.exe` CLI tool. It is highly recommended to **leave this unchecked**. Unchecked machine backups will successfully upload standard `.img` bare-metal images, which can still be used for disaster recovery or manual VM imports.

## Screenshots

<img width="1480" height="1264" alt="Folderbackup" src="https://github.com/user-attachments/assets/1e3bb685-7f1d-4a24-a453-4fe60dcb2a0e" />

<img width="1479" height="1489" alt="Maschinebackup" src="https://github.com/user-attachments/assets/ec454af6-bf78-4b7a-a11a-dccded6b54ba" />

## Credits

- **Core CLI:** This GUI is a wrapper for the excellent work by [tizbac](https://github.com/tizbac).
- **GUI Development:** This interface was developed and refined with the assistance of **Gemini (Google AI)** to ensure robust error handling and seamless Windows integration.

## License & Disclaimer

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.** The authors and contributors are not liable for any data loss, system damage, or other issues arising from the use of this script or the underlying backup tools. Use at your own risk. Always verify your backups regularly.
