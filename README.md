# proxmoxbackupclient_go-GUI

A lightweight PowerShell-based Graphical User Interface for the [proxmox-backup-client-go](https://github.com/tizbac/proxmoxbackupclient_go) by tizbac. This tool simplifies managing directory and physical drive backups to a Proxmox Backup Server (PBS) from Windows machines.

## Features

- **Dual Mode Backup:** Supports both `pbsdirectorybackup.exe` (for folders) and `pbsmachinebackup.exe` (for physical disk images).
- **Automated Scheduling:** Easily register backup jobs in the Windows Task Scheduler to run under the `SYSTEM` account.
- **Auto-Elevation:** Automatically requests Administrator privileges required for VSS snapshots and disk access.
- **Physical Drive Mapping:** Automatically detects and correctly formats physical drive paths (e.g., `\\.\PhysicalDrive0`) to avoid common CLI syntax errors.
- **Job Management:** Save, edit, and delete multiple backup configurations in a local `backup_jobs.json` file.

## Prerequisites

1. Download the latest Windows release of `proxmox-backup-client-go` from [tizbac's repository](https://github.com/tizbac/proxmoxbackupclient_go/releases).
2. Extract the executables (`pbsdirectorybackup.exe` and `pbsmachinebackup.exe`) into the same folder as this script.

## Setup & Usage

1. Place `proxmoxclient_go_gui.ps1` in the directory containing the PBS executables.
2. Right-click the script and select **Run with PowerShell**.
3. Fill in your PBS details (URL, Fingerprint, Token, Secret).
4. Select **Directory** or **Machine** mode and choose your source.
5. Click **Save Job**, then either **Run Backup Now** to test or **Automate in Task Scheduler** for recurring backups.

## Screenshots

![Folderbackup](https://private-user-images.githubusercontent.com/142032740/591368953-9460cd62-1f8c-4c38-a9af-be911ddab31f.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Nzg2MjM1NjQsIm5iZiI6MTc3ODYyMzI2NCwicGF0aCI6Ii8xNDIwMzI3NDAvNTkxMzY4OTUzLTk0NjBjZDYyLTFmOGMtNGMzOC1hOWFmLWJlOTExZGRhYjMxZi5qcGc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNTEyJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDUxMlQyMjAxMDRaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT03OTRiMTM2NmFmODdjYzczZDRkMmYyYWJiZjIzNjcxMGQ0M2EyOGE1ZWQ5ZWRkNzUwMzAzMTAyNzQ2NzNhMGVlJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZqcGVnIn0.Mcot9F-ZSYA6m6eallSmR2SsboCtLUj9HaGJjbaeBaU) 

![Maschinebackup](https://private-user-images.githubusercontent.com/142032740/591369389-a3510028-d597-41a3-8935-65da88d0a137.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Nzg2MjM1NjQsIm5iZiI6MTc3ODYyMzI2NCwicGF0aCI6Ii8xNDIwMzI3NDAvNTkxMzY5Mzg5LWEzNTEwMDI4LWQ1OTctNDFhMy04OTM1LTY1ZGE4OGQwYTEzNy5qcGc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNTEyJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDUxMlQyMjAxMDRaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0xNzEwZDdhZTg0MDM4MjIzY2Y0NmJiNzliNGI1M2RlMGNlMDg0MmIzMjE2ZThkMjE3ZjQzMGE0ZDBmNTc3OWI0JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZqcGVnIn0.zrZfO3gn3R3invKsPDTg54RI7MWesn8uEFBaeR9mVgU)

*The interface provides a clean, slate-blue themed dashboard for easy configuration.*

## Credits

- **Core CLI:** This GUI is a wrapper for the excellent work by [tizbac](https://github.com/tizbac).
- **GUI Development:** This interface was developed and refined with the assistance of **Gemini (Google AI)** to ensure robust error handling and seamless Windows integration.

## License & Disclaimer

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.** The authors and contributors are not liable for any data loss, system damage, or other issues arising from the use of this script or the underlying backup tools. Use at your own risk. Always verify your backups regularly.
