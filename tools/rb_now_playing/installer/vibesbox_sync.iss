; VibesBox Sync – Windows Installer (Inno Setup 6/7)
; Wird von build_windows_installer.ps1 aufgerufen.
; MyAppVersion und OutputBaseFilename werden vor dem Compile
; aus pubspec.yaml ueberschrieben.

#define MyAppName "VibesBox Sync"
#define MyAppExeName "VibesBoxSync.exe"
#define MyAppPublisher "VibesBox"
#define MyAppURL "https://vibesbox.app"
#define MyAppVersion "1.0.3"

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
OutputBaseFilename=VibesBoxSync-Setup-1.0.3
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

[Run]
; App nur starten, wenn VC++-Laufzeit vorhanden (sonst VCRUNTIME140_1.dll-Fehler).
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent; Check: VcRuntimeInstalled

[Code]
const
  VcRedistUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe';

var
  VcDownloadOffered: Boolean;

function VcRuntimeInstalled: Boolean;
begin
  { Genau die DLL aus dem Kundenfehlerbild }
  Result := FileExists(ExpandConstant('{sys}\VCRUNTIME140_1.dll'));
end;

procedure OpenVcRedistDownload;
var
  ErrorCode: Integer;
begin
  VcDownloadOffered := True;
  if not ShellExec('open', VcRedistUrl, '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode) then
  begin
    if ActiveLanguage = 'german' then
      MsgBox(
        'Download konnte nicht geoeffnet werden.' + #13#10 +
        'Bitte manuell installieren:' + #13#10 + VcRedistUrl,
        mbError, MB_OK)
    else
      MsgBox(
        'Could not open the download.' + #13#10 +
        'Please install manually:' + #13#10 + VcRedistUrl,
        mbError, MB_OK);
  end;
end;

function AskVcRedistDownload(const Msg: String): Boolean;
begin
  Result := MsgBox(Msg, mbConfirmation, MB_YESNO) = IDYES;
  if Result then
    OpenVcRedistDownload;
end;

function InitializeSetup: Boolean;
var
  Msg: String;
begin
  Result := True;
  VcDownloadOffered := False;
  if VcRuntimeInstalled or WizardSilent then
    Exit;

  if ActiveLanguage = 'german' then
    Msg :=
      'Auf diesem PC fehlt die Microsoft Visual C++ Laufzeitbibliothek' + #13#10 +
      '(VCRUNTIME140_1.dll).' + #13#10 + #13#10 +
      'Ohne dieses Paket kann VibesBox Sync nicht starten.' + #13#10 + #13#10 +
      'Jetzt den kostenlosen Microsoft-Download oeffnen?'
  else
    Msg :=
      'This PC is missing the Microsoft Visual C++ runtime' + #13#10 +
      '(VCRUNTIME140_1.dll).' + #13#10 + #13#10 +
      'VibesBox Sync cannot start without this package.' + #13#10 + #13#10 +
      'Open the free Microsoft download now?';

  AskVcRedistDownload(Msg);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Msg: String;
begin
  if CurStep <> ssPostInstall then
    Exit;
  if VcRuntimeInstalled or WizardSilent or VcDownloadOffered then
    Exit;

  { Nur nochmal fragen, wenn der Download am Anfang abgelehnt wurde }
  if ActiveLanguage = 'german' then
    Msg :=
      'VibesBox Sync wurde installiert, startet aber erst nach Installation der' + #13#10 +
      'Visual C++ Laufzeit (VCRUNTIME140_1.dll).' + #13#10 + #13#10 +
      'Download jetzt oeffnen?'
  else
    Msg :=
      'VibesBox Sync is installed, but it will only start after you install the' + #13#10 +
      'Visual C++ runtime (VCRUNTIME140_1.dll).' + #13#10 + #13#10 +
      'Open the download now?';

  AskVcRedistDownload(Msg);
end;
