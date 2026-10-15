Run from the Windows Listener project folder:

.\scripts\release.ps1                     Build installer and publish (no version bump)
.\scripts\release.ps1 -patch              Bump patch and build/publish installer
.\scripts\release.ps1 -minor              Bump minor and build/publish installer
.\scripts\release.ps1 -major              Bump major and build/publish installer
.\scripts\release.ps1 -patch -m "Fixes"   Add a note to the release commit
.\scripts\release.ps1 -SkipPublish        Build locally without copying, committing, or pushing

Requirements: Flutter Windows build tools and NSIS (see the project README).
Scripts resolve the project folder automatically, so invocation from another folder also works.
Use only one version switch. Each bump also increments the pubspec build number.
A failed build leaves the requested version bump in pubspec.yaml; retry without a bump switch.
Application versions are independent of the shared FSD/TSD documentation version.

Local output: dist\WMSWindowsListenerSetup.exe
Default published output:
E:\Productivity\flutter\Apps\APPSRELEASE\wms_windows_listener\exe\wms_windows_listener-v<version>.exe
Use -ReleaseRepo "D:\path\to\APPSRELEASE" to override the existing release repository.
The default command replaces the same-version installer, commits only that installer,
and runs git push using the repository's configured upstream (including any pending commits).
Source changes, including pubspec.yaml, are not committed by this script.
