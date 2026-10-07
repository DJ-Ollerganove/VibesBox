; VibesBox Sync – Windows Installer (Inno Setup 6/7)
; Wird von build_windows_installer.ps1 aufgerufen.
; MyAppVersion und OutputBaseFilename werden vor dem Compile
; aus pubspec.yaml ueberschrieben.
;
; Sprachen: gleiche Auswahl wie im Sync-Tool (tool_i18n).
; Fehlende/unofficial .isl liegen unter installer/languages/ (inkl. Hindi).
; Hinweis: Der Microsoft VC++-Redist selbst hat kein separates Hindi-UI-Paket.

#define MyAppName "VibesBox Sync"
#define MyAppExeName "VibesBoxSync.exe"
#define MyAppPublisher "VibesBox"
#define MyAppURL "https://vibesbox.app"
#define MyAppVersion "1.0.6"

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
OutputBaseFilename=VibesBoxSync-Setup-1.0.6
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
ShowLanguageDialog=yes

[Languages]
; Name-IDs muessen zu [CustomMessages] passen. English = Default.isl
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"
Name: "czech"; MessagesFile: "compiler:Languages\Czech.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"
; Lokal mitgeliefert (nicht in jeder Inno-Installation unter compiler:Languages)
Name: "chinesesimplified"; MessagesFile: "languages\ChineseSimplified.isl"
Name: "vietnamese"; MessagesFile: "languages\Vietnamese.isl"
Name: "greek"; MessagesFile: "languages\Greek.isl"
Name: "albanian"; MessagesFile: "languages\Albanian.isl"
Name: "thai"; MessagesFile: "languages\Thai.isl"
Name: "hindi"; MessagesFile: "languages\Hindi.isl"

[CustomMessages]
; VC++-Hinweis – parallel zu den Installer-Sprachen (nicht Flutter tool_packs)
english.VcMissing=This PC is missing the Microsoft Visual C++ runtime%n(VCRUNTIME140_1.dll).%n%nVibesBox Sync cannot start without this package.%n%nOpen the free Microsoft download now?
english.VcMissingAfter=VibesBox Sync is installed, but it will only start after you install the Visual C++ runtime (VCRUNTIME140_1.dll).%n%nOpen the download now?
english.VcOpenFail=Could not open the download.%nPlease install manually:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

german.VcMissing=Auf diesem PC fehlt die Microsoft Visual C++ Laufzeitbibliothek%n(VCRUNTIME140_1.dll).%n%nOhne dieses Paket kann VibesBox Sync nicht starten.%n%nJetzt den kostenlosen Microsoft-Download oeffnen?
german.VcMissingAfter=VibesBox Sync wurde installiert, startet aber erst nach Installation der Visual C++ Laufzeit (VCRUNTIME140_1.dll).%n%nDownload jetzt oeffnen?
german.VcOpenFail=Download konnte nicht geoeffnet werden.%nBitte manuell installieren:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

french.VcMissing=Il manque la bibliotheque d'execution Microsoft Visual C++%n(VCRUNTIME140_1.dll) sur ce PC.%n%nSans ce package, VibesBox Sync ne peut pas demarrer.%n%nOuvrir le telechargement Microsoft gratuit maintenant ?
french.VcMissingAfter=VibesBox Sync est installe, mais ne demarrera qu'apres l'installation du runtime Visual C++ (VCRUNTIME140_1.dll).%n%nOuvrir le telechargement maintenant ?
french.VcOpenFail=Impossible d'ouvrir le telechargement.%nVeuillez installer manuellement:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

spanish.VcMissing=Falta el runtime de Microsoft Visual C++%n(VCRUNTIME140_1.dll) en este PC.%n%nSin este paquete, VibesBox Sync no puede iniciarse.%n%nAbrir ahora la descarga gratuita de Microsoft?
spanish.VcMissingAfter=VibesBox Sync esta instalado, pero solo arrancara despues de instalar el runtime Visual C++ (VCRUNTIME140_1.dll).%n%nAbrir la descarga ahora?
spanish.VcOpenFail=No se pudo abrir la descarga.%nInstalelo manualmente:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

italian.VcMissing=Su questo PC manca il runtime Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nSenza questo pacchetto VibesBox Sync non puo avviarsi.%n%nAprire ora il download gratuito Microsoft?
italian.VcMissingAfter=VibesBox Sync e installato, ma si avvia solo dopo l'installazione del runtime Visual C++ (VCRUNTIME140_1.dll).%n%nAprire il download ora?
italian.VcOpenFail=Impossibile aprire il download.%nInstallare manualmente:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

dutch.VcMissing=Op deze pc ontbreekt de Microsoft Visual C++-runtime%n(VCRUNTIME140_1.dll).%n%nZonder dit pakket kan VibesBox Sync niet starten.%n%nNu de gratis Microsoft-download openen?
dutch.VcMissingAfter=VibesBox Sync is geinstalleerd, maar start pas na installatie van de Visual C++-runtime (VCRUNTIME140_1.dll).%n%nDownload nu openen?
dutch.VcOpenFail=Download kon niet worden geopend.%nInstalleer handmatig:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

portuguese.VcMissing=Falta o runtime Microsoft Visual C++%n(VCRUNTIME140_1.dll) neste PC.%n%nSem este pacote, o VibesBox Sync nao consegue iniciar.%n%nAbrir agora a transferencia gratuita da Microsoft?
portuguese.VcMissingAfter=O VibesBox Sync esta instalado, mas so inicia apos instalar o runtime Visual C++ (VCRUNTIME140_1.dll).%n%nAbrir a transferencia agora?
portuguese.VcOpenFail=Nao foi possivel abrir a transferencia.%nInstale manualmente:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

polish.VcMissing=Na tym komputerze brakuje biblioteki Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nBez tego pakietu VibesBox Sync nie moze sie uruchomic.%n%nOtworzyc teraz darmowe pobieranie Microsoft?
polish.VcMissingAfter=VibesBox Sync jest zainstalowany, ale uruchomi sie dopiero po zainstalowaniu runtime Visual C++ (VCRUNTIME140_1.dll).%n%nOtworzyc pobieranie teraz?
polish.VcOpenFail=Nie mozna otworzyc pobierania.%nZainstaluj recznie:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

czech.VcMissing=Na tomto PC chybi runtime Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nBez tohoto balicku nelze VibesBox Sync spustit.%n%nOtevrit nyni bezplatne stazeni Microsoft?
czech.VcMissingAfter=VibesBox Sync je nainstalovan, ale spusti se az po instalaci runtime Visual C++ (VCRUNTIME140_1.dll).%n%nOtevrit stazeni nyni?
czech.VcOpenFail=Stazeni se nepodarilo otevrit.%nNainstalujte rucne:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

greek.VcMissing=Σε αυτόν τον υπολογιστή λείπει το Microsoft Visual C++ runtime%n(VCRUNTIME140_1.dll).%n%nΧωρίς αυτό το πακέτο το VibesBox Sync δεν μπορεί να ξεκινήσει.%n%nΆνοιγμα της δωρεάν λήψης Microsoft τώρα;
greek.VcMissingAfter=Το VibesBox Sync εγκαταστάθηκε, αλλά θα ξεκινήσει μόνο μετά την εγκατάσταση του Visual C++ runtime (VCRUNTIME140_1.dll).%n%nΆνοιγμα λήψης τώρα;
greek.VcOpenFail=Δεν ήταν δυνατό το άνοιγμα της λήψης.%nΕγκαταστήστε χειροκίνητα:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

russian.VcMissing=На этом ПК отсутствует среда Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nБез этого пакета VibesBox Sync не запускается.%n%nОткрыть бесплатную загрузку Microsoft сейчас?
russian.VcMissingAfter=VibesBox Sync установлен, но запустится только после установки среды Visual C++ (VCRUNTIME140_1.dll).%n%nОткрыть загрузку сейчас?
russian.VcOpenFail=Не удалось открыть загрузку.%nУстановите вручную:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

ukrainian.VcMissing=На цьому ПК відсутня бібліотека Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nБез цього пакета VibesBox Sync не запускається.%n%nВідкрити безкоштовне завантаження Microsoft зараз?
ukrainian.VcMissingAfter=VibesBox Sync встановлено, але запуститься лише після встановлення Visual C++ (VCRUNTIME140_1.dll).%n%nВідкрити завантаження зараз?
ukrainian.VcOpenFail=Не вдалося відкрити завантаження.%nВстановіть вручну:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

turkish.VcMissing=Bu bilgisayarda Microsoft Visual C++ calisma zamani%n(VCRUNTIME140_1.dll) eksik.%n%nBu paket olmadan VibesBox Sync baslatilamaz.%n%nUcretsiz Microsoft indirmesini simdi acmak ister misiniz?
turkish.VcMissingAfter=VibesBox Sync kuruldu, ancak Visual C++ calisma zamani (VCRUNTIME140_1.dll) kurulana kadar baslamaz.%n%nIndirmeyi simdi ac?
turkish.VcOpenFail=Indirme acilamadi.%nLutfen elle kurun:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

arabic.VcMissing=هذا الجهاز يفتقد مكتبة تشغيل Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nبدون هذه الحزمة لا يمكن تشغيل VibesBox Sync.%n%nفتح تنزيل Microsoft المجاني الآن؟
arabic.VcMissingAfter=تم تثبيت VibesBox Sync، لكنه يعمل فقط بعد تثبيت مكتبة Visual C++ (VCRUNTIME140_1.dll).%n%nفتح التنزيل الآن؟
arabic.VcOpenFail=تعذر فتح التنزيل.%nثبّت يدوياً:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

japanese.VcMissing=このPCには Microsoft Visual C++ ランタイム%n(VCRUNTIME140_1.dll) がありません。%n%nこのパッケージがないと VibesBox Sync は起動できません。%n%n無料の Microsoft ダウンロードを今すぐ開きますか？
japanese.VcMissingAfter=VibesBox Sync はインストールされましたが、Visual C++ ランタイム (VCRUNTIME140_1.dll) のインストール後にのみ起動します。%n%n今すぐダウンロードを開きますか？
japanese.VcOpenFail=ダウンロードを開けませんでした。%n手動でインストールしてください:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

chinesesimplified.VcMissing=此电脑缺少 Microsoft Visual C++ 运行库%n(VCRUNTIME140_1.dll)。%n%n没有该组件时 VibesBox Sync 无法启动。%n%n现在打开免费的 Microsoft 下载吗？
chinesesimplified.VcMissingAfter=VibesBox Sync 已安装，但需先安装 Visual C++ 运行库 (VCRUNTIME140_1.dll) 才能启动。%n%n现在打开下载吗？
chinesesimplified.VcOpenFail=无法打开下载。%n请手动安装:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

vietnamese.VcMissing=May tinh nay thieu thu vien Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nKhong co goi nay thi VibesBox Sync khong the khoi dong.%n%nMo ban tai Microsoft mien phi ngay bay gio?
vietnamese.VcMissingAfter=VibesBox Sync da duoc cai dat, nhung chi chay sau khi cai Visual C++ runtime (VCRUNTIME140_1.dll).%n%nMo ban tai ngay bay gio?
vietnamese.VcOpenFail=Khong mo duoc ban tai.%nVui long cai thu cong:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

albanian.VcMissing=Ne kete PC mungon biblioteka Microsoft Visual C++%n(VCRUNTIME140_1.dll).%n%nPa kete pakete VibesBox Sync nuk mund te niset.%n%nTe hapet tani shkarkimi falas i Microsoft?
albanian.VcMissingAfter=VibesBox Sync u instalua, por niset vetem pasi te instaloni runtime Visual C++ (VCRUNTIME140_1.dll).%n%nTe hapet shkarkimi tani?
albanian.VcOpenFail=Shkarkimi nuk u hap.%nInstaloni manualisht:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

thai.VcMissing=พีซีเครื่องนี้ยังไม่มี Microsoft Visual C++ runtime%n(VCRUNTIME140_1.dll)%n%nหากไม่มีแพ็กเกจนี้ VibesBox Sync จะเริ่มไม่ได้%n%nเปิดดาวน์โหลดฟรีจาก Microsoft ตอนนี้เลยหรือไม่?
thai.VcMissingAfter=ติดตั้ง VibesBox Sync แล้ว แต่จะเริ่มได้หลังจากติดตั้ง Visual C++ runtime (VCRUNTIME140_1.dll)%n%nเปิดดาวน์โหลดตอนนี้เลยหรือไม่?
thai.VcOpenFail=เปิดดาวน์โหลดไม่ได้%nติดตั้งด้วยตนเอง:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

hindi.VcMissing=इस पीसी पर Microsoft Visual C++ रनटाइम मौजूद नहीं है%n(VCRUNTIME140_1.dll)।%n%nइस पैकेज के बिना VibesBox Sync शुरू नहीं हो सकता।%n%nक्या अभी Microsoft का मुफ़्त डाउनलोड खोला जाए?
hindi.VcMissingAfter=VibesBox Sync इंस्टॉल हो गया है, लेकिन Visual C++ रनटाइम (VCRUNTIME140_1.dll) इंस्टॉल करने के बाद ही चलेगा।%n%nक्या अभी डाउनलोड खोला जाए?
hindi.VcOpenFail=डाउनलोड नहीं खोला जा सका।%nकृपया मैन्युअली इंस्टॉल करें:%nhttps://aka.ms/vs/17/release/vc_redist.x64.exe

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
    MsgBox(ExpandConstant('{cm:VcOpenFail}'), mbError, MB_OK);
end;

function AskVcRedistDownload(const Msg: String): Boolean;
begin
  Result := MsgBox(Msg, mbConfirmation, MB_YESNO) = IDYES;
  if Result then
    OpenVcRedistDownload;
end;

function InitializeSetup: Boolean;
begin
  Result := True;
  VcDownloadOffered := False;
  if VcRuntimeInstalled or WizardSilent then
    Exit;

  AskVcRedistDownload(ExpandConstant('{cm:VcMissing}'));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then
    Exit;
  if VcRuntimeInstalled or WizardSilent or VcDownloadOffered then
    Exit;

  { Nur nochmal fragen, wenn der Download am Anfang abgelehnt wurde }
  AskVcRedistDownload(ExpandConstant('{cm:VcMissingAfter}'));
end;
