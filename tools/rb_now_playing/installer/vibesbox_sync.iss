; VibesBox Sync – Windows Installer (Inno Setup 6/7)
; Wird von build_windows_installer.ps1 aufgerufen.
; MyAppVersion und OutputBaseFilename werden vor dem Compile
; aus pubspec.yaml ueberschrieben.

#define MyAppName "VibesBox Sync"
#define MyAppExeName "VibesBoxSync.exe"
#define MyAppPublisher "VibesBox"
#define MyAppURL "https://vibesbox.app"
#define MyAppVersion "1.0.5"

[Setup]
AppId={{A7C3E9B1-4D2F-4F8A-9C11-6E2B8D0F4A71}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=VibesBoxSync-Setup-1.0.4
SetupIconFile=vibesbox_sync.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Komplettes Flutter Release-Bundle (EXE + DLLs + data\)
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; IconIndex: 0
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; IconIndex: 0; Tasks: desktopicon

; DJ-Watchdog: Default an – Run-Key + sofortiger Watcher-Start (passt zu Prefs-Default).
; Nutzer kann den Haken „Mit der Dj-Software starten“ in den Einstellungen abschalten.
[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "VibesBoxSyncDjWatch"; ValueData: """{app}\{#MyAppExeName}"" --dj-watch"; Flags: uninsdeletevalue

[Run]
; Watcher sofort nach Setup starten (auch vor erstem UI-Start).
Filename: "{app}\{#MyAppExeName}"; Parameters: "--dj-watch"; Flags: nowait skipifsilent runhidden
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
