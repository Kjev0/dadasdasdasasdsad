; Fermata for Windows (x64): Inno Setup 6 script.
;
; Build with tool/package_windows.ps1, or directly:
;   ISCC.exe /DAppVersion=1.2.3 /DAppVersionNumeric=1.2.3.4 ^
;            /DSourceDir=C:\src\fermata\build\windows\x64\runner\Release ^
;            packaging\windows\fermata.iss
; Output: dist\setup.exe (relative to the repository root).
;
; Requires Inno Setup 6.3 or newer (x64compatible architecture identifier).
; Relative paths below are relative to this file's directory. This file is
; UTF-8 (with BOM) because of the Danish texts.
;
; Optional defines:
;   /DOutputDir=<dir>          output directory (default: ..\..\dist)
;   /DDataCompany=<name>       CompanyName and ProductName from
;   /DDataProduct=<name>       windows\runner\Runner.rc; the app's data lives in
;                              %APPDATA%\<CompanyName>\<ProductName> (path_provider)
;   /DSignTool=<name>          sign setup.exe and the uninstaller with the sign
;                              tool defined via ISCC /S<name>=... (docs/RELEASING.md)

#ifndef AppVersion
  #error Pass the version: ISCC /DAppVersion=<x.y.z> (tool/package_windows.ps1 does this).
#endif
#ifndef AppVersionNumeric
  ; VersionInfoVersion must be numeric (up to four parts).
  #define AppVersionNumeric AppVersion
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef DataCompany
  #define DataCompany "Fermata"
#endif
#ifndef DataProduct
  #define DataProduct "Fermata"
#endif

#define AppName "Fermata"
#define AppExeName "fermata.exe"
#define AppUserModelId "app.fermata.player"
#define AppPublisher "Fermata contributors"
#define AppURL "https://github.com/kjev0/dadasdasdasasdsad"

[Setup]
; Never change AppId: it identifies the installation for upgrades and uninstall.
AppId={{060486A3-49D2-497E-8C64-D42F1D433C6D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
AppCopyright=Copyright (C) 2026 {#AppPublisher}
VersionInfoVersion={#AppVersionNumeric}
VersionInfoProductVersion={#AppVersionNumeric}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup

; Per-user install by default (no UAC prompt); the dialog lets the user choose
; "Install for all users" instead. {autopf} = %LOCALAPPDATA%\Programs per user,
; C:\Program Files for all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; The HKCU Run value (start on sign-in) is a per-user setting by design.
UsedUserAreasWarning=no
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

; Setup (upgrades) closes a running Fermata through the Restart Manager;
; "force" because Fermata hides to the tray instead of exiting when asked to
; close. The uninstaller closes it in [Code] (InitializeUninstall).
CloseApplications=force
RestartApplications=no

SetupIconFile=installer_icon.ico
WizardImageFile=wizard_image.bmp
WizardSmallImageFile=wizard_small.bmp
WizardStyle=modern
ShowLanguageDialog=auto
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

OutputDir={#OutputDir}
OutputBaseFilename=setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
SetupLogging=yes
#ifdef SignTool
SignTool={#SignTool}
SignedUninstaller=yes
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "danish"; MessagesFile: "compiler:Languages\Danish.isl"

[CustomMessages]
english.AppComment=Play your music library and streaming services in one place
danish.AppComment=Afspil dit musikbibliotek og dine streamingtjenester ét sted
english.StartupGroup=Startup:
danish.StartupGroup=Opstart:
english.StartOnSignIn=Start Fermata when I sign in (minimized to the tray)
danish.StartOnSignIn=Start Fermata, når jeg logger på (minimeret til systembakken)
english.RemoveUserDataPrompt=Do you also want to remove your Fermata data?%n%nThis deletes your library database, playlists, settings, cache and saved sign-ins. Music you downloaded to your Music\Fermata folder is not deleted.%n%nChoose No to keep your data for a later reinstall.
danish.RemoveUserDataPrompt=Vil du også fjerne dine Fermata-data?%n%nDette sletter din biblioteksdatabase, dine playlister, indstillinger, cache og gemte loginoplysninger. Musik, du har downloadet til mappen Musik\Fermata, slettes ikke.%n%nVælg Nej for at beholde dine data til en senere geninstallation.
english.CloseFermataPrompt=Fermata is running.%n%nClick OK to close it and continue, or Cancel to stop.
danish.CloseFermataPrompt=Fermata kører.%n%nKlik på OK for at lukke programmet og fortsætte, eller på Annuller for at stoppe.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "{cm:StartOnSignIn}"; GroupDescription: "{cm:StartupGroup}"; Flags: unchecked

[InstallDelete]
; Assets of the previous version (renamed/removed files must not linger).
Type: filesandordirs; Name: "{app}\data\flutter_assets"; Check: IsUpgrade

[Files]
#ifdef SignTool
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion signonce
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "\{#AppExeName},*.pdb,*.lib,*.exp,*.ilk"; Flags: ignoreversion recursesubdirs createallsubdirs
#else
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,*.lib,*.exp,*.ilk"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif

[Icons]
; AppUserModelID must match the ID the running app uses, so the Start menu
; entry, taskbar button, media overlay (SMTC) and notifications group together.
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Comment: "{cm:AppComment}"; AppUserModelID: "{#AppUserModelId}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Comment: "{cm:AppComment}"; AppUserModelID: "{#AppUserModelId}"; Tasks: desktopicon

[Registry]
; Same value the in-app "Start on login" setting writes (lib/platform/windows).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Fermata"; ValueData: """{app}\{#AppExeName}"" --minimized"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  RunValueName = 'Fermata';

var
  RemoveUserData: Boolean;

{ True when installing over an existing installation. }
function IsUpgrade: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\{#AppExeName}'));
end;

{ Command-line switch given to the uninstaller, e.g. /REMOVEUSERDATA. }
function HasSwitch(const Name: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Name) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

{ Closes Fermata processes started from ExePath (asks first unless silent).
  Returns False if the user chose to stop. }
function CloseRunningFermata(const ExePath: String): Boolean;
var
  Locator, Service, Processes, Process: Variant;
  I, Found: Integer;
begin
  Result := True;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Processes := Service.ExecQuery('SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = ''{#AppExeName}''');
    Found := 0;
    for I := 0 to Processes.Count - 1 do
    begin
      Process := Processes.ItemIndex(I);
      if (not VarIsNull(Process.ExecutablePath)) and SameText(Process.ExecutablePath, ExePath) then
        Found := Found + 1;
    end;
    if Found = 0 then
      Exit;
    if not UninstallSilent then
      if SuppressibleMsgBox(CustomMessage('CloseFermataPrompt'), mbConfirmation, MB_OKCANCEL, IDOK) <> IDOK then
      begin
        Result := False;
        Exit;
      end;
    for I := 0 to Processes.Count - 1 do
    begin
      Process := Processes.ItemIndex(I);
      if (not VarIsNull(Process.ExecutablePath)) and SameText(Process.ExecutablePath, ExePath) then
      begin
        Log('Closing the running Fermata');
        Process.Terminate();
      end;
    end;
    Sleep(1500);
  except
    Log('Could not check for a running Fermata: ' + GetExceptionMessage);
  end;
end;

function InitializeUninstall: Boolean;
begin
  Result := CloseRunningFermata(ExpandConstant('{app}\{#AppExeName}'));
end;

{ The in-app "Start on login" setting may have written the Run value even if
  the setup task was not chosen; never leave it pointing at a removed exe. }
procedure RemoveAutostartValue;
var
  Value: String;
begin
  if RegQueryStringValue(HKEY_CURRENT_USER, RunKey, RunValueName, Value) then
    if Pos(LowerCase(ExpandConstant('{app}\{#AppExeName}')), LowerCase(Value)) > 0 then
      RegDeleteValue(HKEY_CURRENT_USER, RunKey, RunValueName);
end;

{ %APPDATA%\<CompanyName>\<ProductName> (library, settings, encrypted
  sign-ins, logs) and %LOCALAPPDATA%\<CompanyName>\<ProductName> (cache). }
procedure DeleteDataDir(const Dir, Parent: String);
begin
  if DirExists(Dir) then
  begin
    if DelTree(Dir, True, True, True) then
      Log('Deleted ' + Dir)
    else
      Log('Could not delete ' + Dir);
  end;
  { Removes the CompanyName folder only if it is now empty. }
  RemoveDir(Parent);
end;

procedure DeleteUserData;
begin
  DeleteDataDir(ExpandConstant('{userappdata}\{#DataCompany}\{#DataProduct}'), ExpandConstant('{userappdata}\{#DataCompany}'));
  DeleteDataDir(ExpandConstant('{localappdata}\{#DataCompany}\{#DataProduct}'), ExpandConstant('{localappdata}\{#DataCompany}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  case CurUninstallStep of
    usUninstall:
      begin
        { Silent uninstalls keep the data unless /REMOVEUSERDATA is given. }
        if UninstallSilent then
          RemoveUserData := HasSwitch('/REMOVEUSERDATA')
        else
          RemoveUserData := SuppressibleMsgBox(CustomMessage('RemoveUserDataPrompt'),
            mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES;
        RemoveAutostartValue;
      end;
    usPostUninstall:
      if RemoveUserData then
        DeleteUserData;
  end;
end;
