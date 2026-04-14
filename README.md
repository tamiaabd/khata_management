# khata_management

this project is created for shuab bhai for his gass business

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Auto Update Pipeline

This project includes GitHub-based auto update support:

- On every push to `main` or `master`, GitHub Actions builds:
  - Windows `.msix`
  - Android `.apk`
- A GitHub Release is automatically created with tag format:
  - `v<app-version>+<github-run-number>`
- The app checks GitHub `releases/latest` and shows an update dialog when a newer release is available.
- When user clicks update:
  - Windows: download `.msix` and open installer
  - Android: download `.apk` and open package installer
- Release now also includes `khata_windows_bundle.rar` containing:
  - `KhataManagement.msix`
  - `KhataManagement.cer`
  - `install_msix.bat`

### Windows MSIX signing setup (self-created certificate)

1. Generate a certificate locally:
   - Run `scripts/windows/create_signing_cert.ps1`
2. Add GitHub repository secrets:
   - `WIN_CERT_PFX_BASE64` -> content of `*.pfx.base64.txt`
   - `WIN_CERT_CER_BASE64` -> content of `*.cer.base64.txt`
   - `WIN_CERT_PASSWORD` -> certificate password
3. Push code. Workflow signs MSIX using your certificate and publishes both direct `.msix` and `.rar` bundle.

Important:
- Never upload your `.pfx` file directly in the repository.
- `.cer` is safe to share and is included in the bundle for installation.

### Why GitHub Actions may not run

- The workflow file must be pushed to the same branch you are pushing code to.
- Your branch name must match workflow trigger (`main` or `master`).
- Repository Actions must be enabled in GitHub settings.

### Where builds are available

- **Actions tab**:
  - Open a workflow run, then download artifacts (`windows-msix`, `windows-rar-bundle`, `android-apk`).
- **Releases tab**:
  - Open latest auto release, download `.msix` / `.apk` assets directly.
  - Download `khata_windows_bundle.rar` for one-click install package.
