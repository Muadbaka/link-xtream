; سكربت إنشاء مثبّت Link Xtream — Inno Setup 6
; الناتج: dist\Link-Xtream-Setup-1.7.2.exe

#define MyAppName "Link Xtream"
#define MyAppVersion "1.7.2"
#define MyAppPublisher "Link Co"
#define MyAppURL "https://www.linkco.ly"
#define MyAppExeName "link_xtream.exe"

[Setup]
; معرّف ثابت للتطبيق حتى تتعرّف النسخ الجديدة على التثبيت السابق
AppId={{C4E1B7A2-9F3D-4B6E-8A21-7D5C0F9B3E64}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=Link-Xtream-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
CloseApplications=yes
RestartApplications=no
VersionInfoVersion=1.7.2.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
; نسخة نظيفة: لا تُحزَّم أي بيانات مستخدم — بيانات التطبيق تُنشأ فارغة
; في %APPDATA%\Link Co\Link Xtream عند أول تشغيل.

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  AppIdValue = 'link-xtream';
  MarkerFolder = 'Link Co\Link Xtream';
  MarkerFileName = 'install.dat';

{ سطور ملف العلامة الذي يتحقق منه التطبيق عند كل تشغيل }
function MarkerLines: TArrayOfString;
var
  Lines: TArrayOfString;
  Token: String;
begin
  Token := GetSHA256OfString(
    GetDateTimeString('yyyymmddhhnnss', '-', ':') + '|' +
    GetComputerNameString + '|' +
    GetUserNameString + '|' +
    ExpandConstant('{app}'));

  SetArrayLength(Lines, 4);
  Lines[0] := 'app_id=' + AppIdValue;
  Lines[1] := 'install_path=' + ExpandConstant('{app}');
  Lines[2] := 'token=' + Token;
  Lines[3] := 'installed_at=' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':');
  Result := Lines;
end;

{ كتابة ملف العلامة داخل مجلد أساسي (ProgramData أو LocalAppData) }
procedure WriteMarkerFile(const BaseDir: String);
var
  Dir: String;
begin
  Dir := BaseDir + '\' + MarkerFolder;
  if not ForceDirectories(Dir) then
    Exit;
  SaveStringsToUTF8File(Dir + '\' + MarkerFileName, MarkerLines, False);
end;

{ كتابة العلامة في مسارين لضمان قراءتها مهما كانت صلاحيات المستخدم }
procedure WriteInstallMarkers;
begin
  WriteMarkerFile(ExpandConstant('{commonappdata}'));
  WriteMarkerFile(ExpandConstant('{localappdata}'));
end;

{ حذف ملفات العلامة عند إلغاء التثبيت }
procedure DeleteInstallMarkers;
var
  Dir: String;
begin
  Dir := ExpandConstant('{commonappdata}') + '\' + MarkerFolder;
  if FileExists(Dir + '\' + MarkerFileName) then
    DeleteFile(Dir + '\' + MarkerFileName);
  if DirExists(Dir) then
    RemoveDir(Dir);

  Dir := ExpandConstant('{localappdata}') + '\' + MarkerFolder;
  if FileExists(Dir + '\' + MarkerFileName) then
    DeleteFile(Dir + '\' + MarkerFileName);
  if DirExists(Dir) then
    RemoveDir(Dir);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    WriteInstallMarkers;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    DeleteInstallMarkers;
end;

