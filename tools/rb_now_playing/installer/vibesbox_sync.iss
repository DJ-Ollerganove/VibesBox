; VibesBox Sync – Windows Installer (Inno Setup 6/7)
; Wird von build_windows_installer.ps1 aufgerufen.
; MyAppVersion und OutputBaseFilename werden vor dem Compile
; aus pubspec.yaml ueberschrieben.

#define MyAppName "VibesBox Sync"
#define MyAppExeName "VibesBoxSync.exe"
#define MyAppPublisher "VibesBox"
#define MyAppURL "https://vibesbox.app"
#define MyAppVersion "1.0.9"

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
OutputBaseFilename=VibesBoxSync-Setup-1.0.9
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
; Always show the language list. English is first so an unknown Windows locale falls back to English.
ShowLanguageDialog=yes

[Languages]
; Inno Setup 6.5 or 7. Files live next to this script (installer\languages).
; English stays first: it is the fallback when Windows has none of these languages.
Name: "en"; MessagesFile: "languages\English.isl"
Name: "sq"; MessagesFile: "languages\Albanian.isl"
Name: "ar"; MessagesFile: "languages\Arabic.isl"
Name: "bg"; MessagesFile: "languages\Bulgarian.isl"
Name: "zh"; MessagesFile: "languages\ChineseSimplified.isl"
Name: "hr"; MessagesFile: "languages\Croatian.isl"
Name: "cs"; MessagesFile: "languages\Czech.isl"
Name: "nl"; MessagesFile: "languages\Dutch.isl"
Name: "fr"; MessagesFile: "languages\French.isl"
Name: "de"; MessagesFile: "languages\German.isl"
Name: "el"; MessagesFile: "languages\Greek.isl"
Name: "hi"; MessagesFile: "languages\Hindi.islu"
Name: "hu"; MessagesFile: "languages\Hungarian.isl"
Name: "it"; MessagesFile: "languages\Italian.isl"
Name: "ja"; MessagesFile: "languages\Japanese.isl"
Name: "pl"; MessagesFile: "languages\Polish.isl"
Name: "pt"; MessagesFile: "languages\Portuguese.isl"
Name: "ro"; MessagesFile: "languages\Romanian.isl"
Name: "ru"; MessagesFile: "languages\Russian.isl"
Name: "sr"; MessagesFile: "languages\SerbianCyrillic.isl"
Name: "es"; MessagesFile: "languages\Spanish.isl"
Name: "th"; MessagesFile: "languages\Thai.isl"
Name: "tr"; MessagesFile: "languages\Turkish.isl"
Name: "uk"; MessagesFile: "languages\Ukrainian.isl"
Name: "vi"; MessagesFile: "languages\Vietnamese.isl"

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
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
