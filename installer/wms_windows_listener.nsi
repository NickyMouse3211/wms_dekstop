Unicode True
!include "MUI2.nsh"

Name "WMS Windows Listener"
OutFile "..\dist\WMSWindowsListenerSetup.exe"
InstallDir "$LOCALAPPDATA\Programs\WMS Windows Listener"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Indonesian"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\build\windows\x64\runner\Release\*"
  CreateDirectory "$SMPROGRAMS\WMS Windows Listener"
  CreateShortCut "$SMPROGRAMS\WMS Windows Listener\WMS Windows Listener.lnk" "$INSTDIR\wms_windows_listener.exe"
  CreateShortCut "$SMPROGRAMS\WMS Windows Listener\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortCut "$SMSTARTUP\WMS Windows Listener.lnk" "$INSTDIR\wms_windows_listener.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WmsWindowsListener" "DisplayName" "WMS Windows Listener"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WmsWindowsListener" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WmsWindowsListener" "DisplayVersion" "1.0.0"
SectionEnd

Section "Uninstall"
  Delete "$SMSTARTUP\WMS Windows Listener.lnk"
  RMDir /r "$SMPROGRAMS\WMS Windows Listener"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WmsWindowsListener"
  ; Settings in %APPDATA% are kept so reinstalling retains the selected folder.
SectionEnd
