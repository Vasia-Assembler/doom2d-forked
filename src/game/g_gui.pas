(* Copyright (C)  Doom 2D: Forever Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)
{$INCLUDE ../shared/a_modes.inc}
unit g_gui;

interface

  uses
    {$IFDEF USE_MEMPOOL}
      mempool,
    {$ENDIF}
    g_base, g_playermodel, MAPDEF, utils
  ;

const

  MAINMENU_ITEMS_COLOR: TRGB = (R:255; G:255; B:255);
  MAINMENU_UNACTIVEITEMS_COLOR: TRGB = (R:192; G:192; B:192);
  MAINMENU_HEADER_COLOR: TRGB = (R:255; G:255; B:255);
  MAINMENU_SPACE = 4;
  MAINMENU_MARKERDELAY = 24;

  MENU_ITEMSTEXT_COLOR: TRGB = (R:255; G:255; B:255);
  MENU_UNACTIVEITEMS_COLOR: TRGB = (R:128; G:128; B:128);
  MENU_ITEMSCTRL_COLOR: TRGB = (R:255; G:0; B:0);
  MENU_VSPACE = 2;
  MENU_HSPACE = 32;
  MENU_MARKERDELAY = 24;

  MAPPREVIEW_WIDTH = 8;
  MAPPREVIEW_HEIGHT = 8;

  KEYREAD_QUERY = '<...>';
  KEYREAD_CLEAR = '???';

  WINDOW_CLOSESOUND = 'MENU_CLOSE';
  MAINMENU_CLICKSOUND = 'MENU_SELECT';
  MAINMENU_CHANGESOUND = 'MENU_CHANGE';
  MENU_CLICKSOUND = 'MENU_SELECT';
  MENU_CHANGESOUND = 'MENU_CHANGE';
  SCROLL_ADDSOUND = 'SCROLL_ADD';
  SCROLL_SUBSOUND = 'SCROLL_SUB';

  WM_KEYDOWN = 101;
  WM_CHAR    = 102;
  WM_USER    = 110;

  MESSAGE_DIKEY = WM_USER + 1;

type
  TMessage = record
    Msg: DWORD;
    wParam: LongInt;
    lParam: LongInt;
  end;

  TGUIControl = class;
  TGUIWindow = class;

  TOnKeyDownEvent = procedure(Key: Byte);
  TOnKeyDownEventEx = procedure(win: TGUIWindow; Key: Byte);
  TOnCloseEvent = procedure;
  TOnShowEvent = procedure;
  TOnClickEvent = procedure;
  TOnChangeEvent = procedure(Sender: TGUIControl);
  TOnEnterEvent = procedure(Sender: TGUIControl);

  TGUIControl = class{$IFDEF USE_MEMPOOL}(TPoolObject){$ENDIF}
  private
    FX, FY: Integer;
    FEnabled: Boolean;
    FWindow : TGUIWindow;
    FName: string;
    FUserData: Pointer;
    FRightAlign: Boolean; //HACK! this works only for "normal" menus, only for menu text labels, and generally sux. sorry.
    FMaxWidth: Integer; //HACK! used for right-aligning labels
  public
    constructor Create;
    procedure OnMessage(var Msg: TMessage); virtual;
    procedure Update; virtual;
    function GetWidth(): Integer; virtual;
    function GetHeight(): Integer; virtual;
    function WantActivationKey (key: LongInt): Boolean; virtual;
    property X: Integer read FX write FX;
    property Y: Integer read FY write FY;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Name: string read FName write FName;
    property UserData: Pointer read FUserData write FUserData;
    property RightAlign: Boolean read FRightAlign write FRightAlign; // for menu
    property CMaxWidth: Integer read FMaxWidth;

    property Window: TGUIWindow read FWindow;
  end;

  TGUIWindow = class{$IFDEF USE_MEMPOOL}(TPoolObject){$ENDIF}
  private
    FActiveControl: TGUIControl;
    FDefControl: string;
    FPrevWindow: TGUIWindow;
    FName: string;
    FBackTexture: string;
    FMainWindow: Boolean;
    FOnKeyDown: TOnKeyDownEvent;
    FOnKeyDownEx: TOnKeyDownEventEx;
    FOnCloseEvent: TOnCloseEvent;
    FOnShowEvent: TOnShowEvent;
    FUserData: Pointer;
  public
    Childs: array of TGUIControl;
    constructor Create(Name: string);
    destructor Destroy; override;
    function AddChild(Child: TGUIControl): TGUIControl;
    procedure OnMessage(var Msg: TMessage);
    procedure Update;
    procedure SetActive(Control: TGUIControl);
    function GetControl(Name: string): TGUIControl;
    property OnKeyDown: TOnKeyDownEvent read FOnKeyDown write FOnKeyDown;
    property OnKeyDownEx: TOnKeyDownEventEx read FOnKeyDownEx write FOnKeyDownEx;
    property OnClose: TOnCloseEvent read FOnCloseEvent write FOnCloseEvent;
    property OnShow: TOnShowEvent read FOnShowEvent write FOnShowEvent;
    property Name: string read FName;
    property DefControl: string read FDefControl write FDefControl;
    property BackTexture: string read FBackTexture write FBackTexture;
    property MainWindow: Boolean read FMainWindow write FMainWindow;
    property UserData: Pointer read FUserData write FUserData;

    property ActiveControl: TGUIControl read FActiveControl;
  end;

  TGUITextButton = class(TGUIControl)
  private
    FText: string;
    FColor: TRGB;
    FBigFont: Boolean;
    FSound: string;
    FShowWindow: string;
  public
    Proc: procedure;
    ProcEx: procedure (sender: TGUITextButton);
    constructor Create(aProc: Pointer; BigFont: Boolean; Text: string);
    destructor Destroy(); override;
    procedure OnMessage(var Msg: TMessage); override;
    procedure Update(); override;
    procedure Click(Silent: Boolean = False);
    property Caption: string read FText write FText;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;
    property ShowWindow: string read FShowWindow write FShowWindow;
  end;

  TGUILabel = class(TGUIControl)
  private
    FText: string;
    FColor: TRGB;
    FBigFont: Boolean;
    FFixedLen: Word;
    FOnClickEvent: TOnClickEvent;
  public
    constructor Create(Text: string; BigFont: Boolean);
    procedure OnMessage(var Msg: TMessage); override;
    property OnClick: TOnClickEvent read FOnClickEvent write FOnClickEvent;
    property FixedLength: Word read FFixedLen write FFixedLen;
    property Text: string read FText write FText;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;
  end;

  TGUIScroll = class(TGUIControl)
  private
    FValue: Integer;
    FMax: Word;
    FOnChangeEvent: TOnChangeEvent;
    procedure FSetValue(a: Integer);
  public
    constructor Create();
    procedure OnMessage(var Msg: TMessage); override;
    procedure Update; override;
    property OnChange: TOnChangeEvent read FOnChangeEvent write FOnChangeEvent;
    property Max: Word read FMax write FMax;
    property Value: Integer read FValue write FSetValue;
  end;

  TGUIItemsList = array of string;

  TGUISwitch = class(TGUIControl)
  private
    FBigFont: Boolean;
    FItems: TGUIItemsList;
    FIndex: Integer;
    FColor: TRGB;
    FOnChangeEvent: TOnChangeEvent;
  public
    constructor Create(BigFont: Boolean);
    procedure OnMessage(var Msg: TMessage); override;
    procedure AddItem(Item: string);
    procedure Update; override;
    function GetText: string;
    property ItemIndex: Integer read FIndex write FIndex;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;
    property OnChange: TOnChangeEvent read FOnChangeEvent write FOnChangeEvent;
    property Items: TGUIItemsList read FItems;
  end;

  TGUIEdit = class(TGUIControl)
  private
    FBigFont: Boolean;
    FCaretPos: Integer;
    FMaxLength: Word;
    FWidth: Word;
    FText: string;
    FColor: TRGB;
    FOnlyDigits: Boolean;
    FOnChangeEvent: TOnChangeEvent;
    FOnEnterEvent: TOnEnterEvent;
    FInvalid: Boolean;
    procedure SetText(Text: string);
  public
    constructor Create(BigFont: Boolean);
    procedure OnMessage(var Msg: TMessage); override;
    procedure Update; override;
    property OnChange: TOnChangeEvent read FOnChangeEvent write FOnChangeEvent;
    property OnEnter: TOnEnterEvent read FOnEnterEvent write FOnEnterEvent;
    property Width: Word read FWidth write FWidth;
    property MaxLength: Word read FMaxLength write FMaxLength;
    property OnlyDigits: Boolean read FOnlyDigits write FOnlyDigits;
    property Text: string read FText write SetText;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;
    property Invalid: Boolean read FInvalid write FInvalid;

    property CaretPos: Integer read FCaretPos;
  end;

  TGUIKeyRead = class(TGUIControl)
  private
    FBigFont: Boolean;
    FColor: TRGB;
    FKey: Word;
    FIsQuery: Boolean;
  public
    constructor Create(BigFont: Boolean);
    procedure OnMessage(var Msg: TMessage); override;
    function WantActivationKey (key: LongInt): Boolean; override;
    property Key: Word read FKey write FKey;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;

    property IsQuery: Boolean read FIsQuery;
  end;

  // can hold two keys
  TGUIKeyRead2 = class(TGUIControl)
  private
    FBigFont: Boolean;
    FColor: TRGB;
    FKey0, FKey1: Word; // this should be an array. sorry.
    FKeyIdx: Integer;
    FIsQuery: Boolean;
    FMaxKeyNameWdt: Integer;
  public
    constructor Create(BigFont: Boolean);
    procedure OnMessage(var Msg: TMessage); override;
    function WantActivationKey (key: LongInt): Boolean; override;
    property Key0: Word read FKey0 write FKey0;
    property Key1: Word read FKey1 write FKey1;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;

    property IsQuery: Boolean read FIsQuery;
    property MaxKeyNameWdt: Integer read FMaxKeyNameWdt;
    property KeyIdx: Integer read FKeyIdx;
  end;

  TGUIModelView = class(TGUIControl)
  private
    FModel: TPlayerModel;
    a: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OnMessage(var Msg: TMessage); override;
    procedure SetModel(ModelName: string);
    procedure SetColor(Red, Green, Blue: Byte);
    procedure NextAnim();
    procedure NextWeapon();
    procedure Update; override;
    property  Model: TPlayerModel read FModel;
  end;

  TPreviewPanel = record
    X1, Y1, X2, Y2: Integer;
    PanelType: Word;
  end;

  TPreviewPanelArray = array of TPreviewPanel;

  TGUIMapPreview = class(TGUIControl)
  private
    FMapData: TPreviewPanelArray;
    FMapSize: TDFPoint;
    FScale: Single;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure OnMessage(var Msg: TMessage); override;
    procedure SetMap(Res: string);
    procedure ClearMap();
    procedure Update(); override;
    function GetScaleStr: String;

    property MapData: TPreviewPanelArray read FMapData;
    property MapSize: TDFPoint read FMapSize;
    property Scale: Single read FScale;
  end;

  TGUIImage = class(TGUIControl)
  private
    FImageRes: string;
    FDefaultRes: string;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure OnMessage(var Msg: TMessage); override;
    procedure SetImage(Res: string);
    procedure ClearImage();
    procedure Update(); override;

    property DefaultRes: string read FDefaultRes write FDefaultRes;
    property ImageRes: string read FImageRes;
  end;

  TGUIListBox = class(TGUIControl)
  private
    FItems: SSArray;
    FActiveColor: TRGB;
    FUnActiveColor: TRGB;
    FBigFont: Boolean;
    FStartLine: Integer;
    FIndex: Integer;
    FWidth: Word;
    FHeight: Word;
    FSort: Boolean;
    FDrawBack: Boolean;
    FDrawScroll: Boolean;
    FOnChangeEvent: TOnChangeEvent;

    procedure FSetItems(Items: SSArray);
    procedure FSetIndex(aIndex: Integer);

  public
    constructor Create(BigFont: Boolean; Width, Height: Word);
    procedure OnMessage(var Msg: TMessage); override;
    procedure AddItem(Item: String);
    function ItemExists (item: String): Boolean;
    procedure SelectItem(Item: String);
    procedure Clear();
    function  SelectedItem(): String;

    property OnChange: TOnChangeEvent read FOnChangeEvent write FOnChangeEvent;
    property Sort: Boolean read FSort write FSort;
    property ItemIndex: Integer read FIndex write FSetIndex;
    property Items: SSArray read FItems write FSetItems;
    property DrawBack: Boolean read FDrawBack write FDrawBack;
    property DrawScrollBar: Boolean read FDrawScroll write FDrawScroll;
    property ActiveColor: TRGB read FActiveColor write FActiveColor;
    property UnActiveColor: TRGB read FUnActiveColor write FUnActiveColor;
    property BigFont: Boolean read FBigFont write FBigFont;

    property Width: Word read FWidth;
    property Height: Word read FHeight;
    property StartLine: Integer read FStartLine;
  end;

  TGUIFileListBox = class(TGUIListBox)
  private
    FSubPath: String;
    FFileMask: String;
    FDirs: Boolean;
    FBaseList: SSArray; // highter index have highter priority

    procedure ScanDirs;

  public
    procedure OnMessage (var Msg: TMessage); override;
    procedure SetBase (dirs: SSArray; path: String = '');
    function  SelectedItem(): String;
    procedure UpdateFileList;

    property Dirs: Boolean read FDirs write FDirs;
    property FileMask: String read FFileMask write FFileMask;
  end;

  TGUIMemo = class(TGUIControl)
  private
    FLines: SSArray;
    FBigFont: Boolean;
    FStartLine: Integer;
    FWidth: Word;
    FHeight: Word;
    FColor: TRGB;
    FDrawBack: Boolean;
    FDrawScroll: Boolean;
  public
    constructor Create(BigFont: Boolean; Width, Height: Word);
    procedure OnMessage(var Msg: TMessage); override;
    procedure Clear;
    procedure SetText(Text: string);
    property DrawBack: Boolean read FDrawBack write FDrawBack;
    property DrawScrollBar: Boolean read FDrawScroll write FDrawScroll;
    property Color: TRGB read FColor write FColor;
    property BigFont: Boolean read FBigFont write FBigFont;

    property Width: Word read FWidth;
    property Height: Word read FHeight;
    property StartLine: Integer read FStartLine;
    property Lines: SSArray read FLines;
  end;

  TGUITextButtonList = array of TGUITextButton;

  TGUIMainMenu = class(TGUIControl)
  private
    FButtons: TGUITextButtonList;
    FHeader: TGUILabel;
    FIndex: Integer;
    FBigFont: Boolean;
    FCounter: Byte; // !!! update it within render
  public
    constructor Create(BigFont: Boolean; Header: string);
    destructor Destroy; override;
    procedure OnMessage(var Msg: TMessage); override;
    function AddButton(fProc: Pointer; Caption: string; ShowWindow: string = ''): TGUITextButton;
    function GetButton(aName: string): TGUITextButton;
    procedure EnableButton(aName: string; e: Boolean);
    procedure AddSpace();
    procedure Update; override;

    property Header: TGUILabel read FHeader;
    property Buttons: TGUITextButtonList read FButtons;
    property Index: Integer read FIndex;
    property Counter: Byte read FCounter;
  end;

  TControlType = class of TGUIControl;

  PMenuItem = ^TMenuItem;
  TMenuItem = record
    Text: TGUILabel;
    ControlType: TControlType;
    Control: TGUIControl;
  end;
  TMenuItemList = array of TMenuItem;

  TGUIMenu = class(TGUIControl)
  private
    FItems: TMenuItemList;
    FHeader: TGUILabel;
    FIndex: Integer;
    FBigFont: Boolean;
    FCounter: Byte;
    FAlign: Boolean;
    FLeft: Integer;
    FYesNo: Boolean;
    function NewItem(): Integer;
  public
    constructor Create(HeaderBigFont, ItemsBigFont: Boolean; Header: string);
    destructor Destroy; override;
    procedure OnMessage(var Msg: TMessage); override;
    procedure AddSpace();
    procedure AddLine(fText: string);
    procedure AddText(fText: string; MaxWidth: Word);
    function AddLabel(fText: string): TGUILabel;
    function AddButton(Proc: Pointer; fText: string; _ShowWindow: string = ''): TGUITextButton;
    function AddScroll(fText: string): TGUIScroll;
    function AddSwitch(fText: string): TGUISwitch;
    function AddEdit(fText: string): TGUIEdit;
    function AddKeyRead(fText: string): TGUIKeyRead;
    function AddKeyRead2(fText: string): TGUIKeyRead2;
    function AddList(fText: string; Width, Height: Word): TGUIListBox;
    function AddFileList(fText: string; Width, Height: Word): TGUIFileListBox;
    function AddMemo(fText: string; Width, Height: Word): TGUIMemo;
    procedure ReAlign();
    function GetControl(aName: string): TGUIControl;
    function GetControlsText(aName: string): TGUILabel;
    procedure Update; override;
    procedure UpdateIndex();
    property Align: Boolean read FAlign write FAlign;
    property Left: Integer read FLeft write FLeft;
    property YesNo: Boolean read FYesNo write FYesNo;

    property Header: TGUILabel read FHeader;
    property Counter: Byte read FCounter;
    property Index: Integer read FIndex;
    property Items: TMenuItemList read FItems;
    property BigFont: Boolean read FBigFont;
  end;

var
  g_GUIWindows: array of TGUIWindow;
  g_ActiveWindow: TGUIWindow = nil;
  g_GUIGrabInput: Boolean = False;

function  g_GUI_AddWindow(Window: TGUIWindow): TGUIWindow;
function  g_GUI_GetWindow(Name: string): TGUIWindow;
procedure g_GUI_ShowWindow(Name: string);
procedure g_GUI_HideWindow(PlaySound: Boolean = True);
function  g_GUI_Destroy(): Boolean;
procedure g_GUI_SaveMenuPos();
procedure g_GUI_LoadMenuPos();


implementation

uses
  {$IFDEF ENABLE_TOUCH}
    g_system,
  {$ENDIF}
  {$IFDEF ENABLE_RENDER}
    r_render,
  {$ENDIF}
  e_input, e_log,
  g_sound, SysUtils, e_res,
  g_game, Math, StrUtils, g_player, g_options, g_console,
  g_map, g_weapons, xdynrec, wadreader;


var
  Saved_Windows: SSArray;

function GetLines (Text: string; BigFont: Boolean; MaxWidth: Word): SSArray;
  var i, j, len, lines: Integer;

  function GetLine (j, i: Integer): String;
  begin
    result := Copy(text, j, i - j + 1);
  end;

  function GetWidth (j, i: Integer): Integer;
    {$IFDEF ENABLE_RENDER}
      var w, h: Integer;
    {$ENDIF}
  begin
    {$IFDEF ENABLE_RENDER}
      r_Render_GetStringSize(BigFont, GetLine(j, i), w, h);
      Result := w;
    {$ELSE}
      Result := 0;
    {$ENDIF}
  end;

begin
  result := nil; lines := 0;
  j := 1; i := 1; len := Length(Text);
  // e_LogWritefln('GetLines @%s len=%s [%s]', [MaxWidth, len, Text]);
  while j <= len do
  begin
    (* --- Get longest possible sequence --- *)
    while (i + 1 <= len) and (GetWidth(j, i + 1) <= MaxWidth) do Inc(i);
    (* --- Do not include part of word --- *)
    if (i < len) and (text[i] <> ' ') then
      while (i >= j) and (text[i] <> ' ') do Dec(i);
    (* --- Do not include spaces --- *)
    while (i >= j) and (text[i] = ' ') do Dec(i);
    (* --- Add line --- *)
    SetLength(result, lines + 1);
    result[lines] := GetLine(j, i);
    // e_LogWritefln('  -> (%s:%s::%s) [%s]', [j, i, GetWidth(j, i), result[lines]]);
    Inc(lines);
    (* --- Skip spaces --- *)
    while (i <= len) and (text[i] = ' ') do Inc(i);
    j := i + 2;
  end;
end;

procedure Sort (var a: SSArray);
  var i, j: Integer; s: string;
begin
  if a = nil then Exit;

  for i := High(a) downto Low(a) do
    for j := Low(a) to High(a) - 1 do
      if LowerCase(a[j]) > LowerCase(a[j + 1]) then
      begin
        s := a[j];
        a[j] := a[j + 1];
        a[j + 1] := s;
      end;
end;

function g_GUI_Destroy(): Boolean;
var
  i: Integer;
begin
  Result := (Length(g_GUIWindows) > 0);

  for i := 0 to High(g_GUIWindows) do
    g_GUIWindows[i].Free();

  g_GUIWindows := nil;
  g_ActiveWindow := nil;
end;

function g_GUI_AddWindow(Window: TGUIWindow): TGUIWindow;
begin
  SetLength(g_GUIWindows, Length(g_GUIWindows)+1);
  g_GUIWindows[High(g_GUIWindows)] := Window;

  Result := Window;
end;

function g_GUI_GetWindow(Name: string): TGUIWindow;
var
  i: Integer;
begin
  Result := nil;

  if g_GUIWindows <> nil then
    for i := 0 to High(g_GUIWindows) do
      if g_GUIWindows[i].FName = Name then
      begin
        Result := g_GUIWindows[i];
        Break;
      end;

  Assert(Result <> nil, 'GUI_Window "'+Name+'" not found');
end;

procedure g_GUI_ShowWindow(Name: string);
var
  i: Integer;
begin
  if g_GUIWindows = nil then
    Exit;

  for i := 0 to High(g_GUIWindows) do
    if g_GUIWindows[i].FName = Name then
    begin
      g_GUIWindows[i].FPrevWindow := g_ActiveWindow;
      g_ActiveWindow := g_GUIWindows[i];

      if g_ActiveWindow.MainWindow then
        g_ActiveWindow.FPrevWindow := nil;

      if g_ActiveWindow.FDefControl <> '' then
        g_ActiveWindow.SetActive(g_ActiveWindow.GetControl(g_ActiveWindow.FDefControl))
      else
        g_ActiveWindow.SetActive(nil);

      if @g_ActiveWindow.FOnShowEvent <> nil then
        g_ActiveWindow.FOnShowEvent();

      Break;
    end;
end;

procedure g_GUI_HideWindow(PlaySound: Boolean = True);
begin
  if g_ActiveWindow <> nil then
  begin
    if @g_ActiveWindow.OnClose <> nil then
      g_ActiveWindow.OnClose();
    g_ActiveWindow := g_ActiveWindow.FPrevWindow;
    if PlaySound then
      g_Sound_PlayEx(WINDOW_CLOSESOUND);
  end;
end;

procedure g_GUI_SaveMenuPos();
var
  len: Integer;
  win: TGUIWindow;
begin
  SetLength(Saved_Windows, 0);
  win := g_ActiveWindow;

  while win <> nil do
  begin
    len := Length(Saved_Windows);
    SetLength(Saved_Windows, len + 1);

    Saved_Windows[len] := win.Name;

    if win.MainWindow then
      win := nil
    else
      win := win.FPrevWindow;
  end;
end;

procedure g_GUI_LoadMenuPos();
var
  i, j, k, len: Integer;
  ok: Boolean;
begin
  g_ActiveWindow := nil;
  len := Length(Saved_Windows);

  if len = 0 then
    Exit;

// ���� � ������� ����:
  g_GUI_ShowWindow(Saved_Windows[len-1]);

// �� ������������� (��� ������ ������):
  if (len = 1) or (g_ActiveWindow = nil) then
    Exit;

// ���� ������ � ��������� �����:
  for k := len-1 downto 1 do
  begin
    ok := False;

    for i := 0 to Length(g_ActiveWindow.Childs)-1 do
    begin
      if g_ActiveWindow.Childs[i] is TGUIMainMenu then
        begin // GUI_MainMenu
          with TGUIMainMenu(g_ActiveWindow.Childs[i]) do
            for j := 0 to Length(FButtons)-1 do
              if FButtons[j].ShowWindow = Saved_Windows[k-1] then
              begin
                FButtons[j].Click(True);
                ok := True;
                Break;
              end;
        end
      else // GUI_Menu
        if g_ActiveWindow.Childs[i] is TGUIMenu then
          with TGUIMenu(g_ActiveWindow.Childs[i]) do
            for j := 0 to Length(FItems)-1 do
              if FItems[j].ControlType = TGUITextButton then
                if TGUITextButton(FItems[j].Control).ShowWindow = Saved_Windows[k-1] then
                begin
                  TGUITextButton(FItems[j].Control).Click(True);
                  ok := True;
                  Break;
                end;

      if ok then
        Break;
    end;

  // �� �������������:
    if (not ok) or
       (g_ActiveWindow.Name = Saved_Windows[k]) then
      Break;
  end;
end;

{ TGUIWindow }

constructor TGUIWindow.Create(Name: string);
begin
  Childs := nil;
  FActiveControl := nil;
  FName := Name;
  FOnKeyDown := nil;
  FOnKeyDownEx := nil;
  FOnCloseEvent := nil;
  FOnShowEvent := nil;
end;

destructor TGUIWindow.Destroy;
var
  i: Integer;
begin
  if Childs = nil then
    Exit;

  for i := 0 to High(Childs) do
    Childs[i].Free();
end;

function TGUIWindow.AddChild(Child: TGUIControl): TGUIControl;
begin
  Child.FWindow := Self;

  SetLength(Childs, Length(Childs) + 1);
  Childs[High(Childs)] := Child;

  Result := Child;
end;

procedure TGUIWindow.Update;
var
  i: Integer;
begin
  for i := 0 to High(Childs) do
    if Childs[i] <> nil then Childs[i].Update;
end;

procedure TGUIWindow.OnMessage(var Msg: TMessage);
begin
  if FActiveControl <> nil then FActiveControl.OnMessage(Msg);
  if @FOnKeyDown <> nil then FOnKeyDown(Msg.wParam);
  if @FOnKeyDownEx <> nil then FOnKeyDownEx(self, Msg.wParam);

  if Msg.Msg = WM_KEYDOWN then
  begin
    case Msg.wParam of
      VK_ESCAPE:
        begin
          g_GUI_HideWindow;
          Exit
        end
    end
  end
end;

procedure TGUIWindow.SetActive(Control: TGUIControl);
begin
  FActiveControl := Control;
end;

function TGUIWindow.GetControl(Name: String): TGUIControl;
var
  i: Integer;
begin
  Result := nil;

  if Childs <> nil then
    for i := 0 to High(Childs) do
      if Childs[i] <> nil then
        if LowerCase(Childs[i].FName) = LowerCase(Name) then
        begin
          Result := Childs[i];
          Break;
        end;

  Assert(Result <> nil, 'Window Control "'+Name+'" not Found!');
end;

{ TGUIControl }

constructor TGUIControl.Create();
begin
  FX := 0;
  FY := 0;

  FEnabled := True;
  FRightAlign := false;
  FMaxWidth := -1;
end;

procedure TGUIControl.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then
    Exit;
end;

procedure TGUIControl.Update();
begin
end;

function TGUIControl.WantActivationKey (key: LongInt): Boolean;
begin
  result := false;
end;

  function TGUIControl.GetWidth (): Integer;
    {$IFDEF ENABLE_RENDER}
      var h: Integer;
    {$ENDIF}
  begin
    {$IFDEF ENABLE_RENDER}
      r_Render_GetControlSize(Self, Result, h);
    {$ELSE}
      Result := 0;
    {$ENDIF}
  end;

  function TGUIControl.GetHeight (): Integer;
    {$IFDEF ENABLE_RENDER}
      var w: Integer;
    {$ENDIF}
  begin
    {$IFDEF ENABLE_RENDER}
      r_Render_GetControlSize(Self, w, Result);
    {$ELSE}
      Result := 0;
    {$ENDIF}
  end;

{ TGUITextButton }

procedure TGUITextButton.Click(Silent: Boolean = False);
begin
  if (FSound <> '') and (not Silent) then g_Sound_PlayEx(FSound);

  if @Proc <> nil then Proc();
  if @ProcEx <> nil then ProcEx(self);

  if FShowWindow <> '' then g_GUI_ShowWindow(FShowWindow);
end;

constructor TGUITextButton.Create(aProc: Pointer; BigFont: Boolean; Text: string);
begin
  inherited Create();

  Self.Proc := aProc;
  ProcEx := nil;

  FBigFont := BigFont;
  FText := Text;
end;

destructor TGUITextButton.Destroy;
begin

 inherited;
end;

procedure TGUITextButton.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then Exit;

  inherited;

  case Msg.Msg of
    WM_KEYDOWN:
      case Msg.wParam of
        IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK: Click();
      end;
  end;
end;

procedure TGUITextButton.Update;
begin
  inherited;
end;

{ TGUIMainMenu }

function TGUIMainMenu.AddButton(fProc: Pointer; Caption: string; ShowWindow: string = ''): TGUITextButton;
  var
    {$IFDEF ENABLE_RENDER}
      lw: Integer;
    {$ENDIF}
    a, _x: Integer;
    h, hh: Word;
    lh: Integer;
begin
  FIndex := 0;

  SetLength(FButtons, Length(FButtons)+1);
  FButtons[High(FButtons)] := TGUITextButton.Create(fProc, FBigFont, Caption);
  FButtons[High(FButtons)].ShowWindow := ShowWindow;
  with FButtons[High(FButtons)] do
  begin
    if (fProc <> nil) or (ShowWindow <> '') then FColor := MAINMENU_ITEMS_COLOR
    else FColor := MAINMENU_UNACTIVEITEMS_COLOR;
    FSound := MAINMENU_CLICKSOUND;
  end;

  _x := gScreenWidth div 2;

  for a := 0 to High(FButtons) do
    if FButtons[a] <> nil then
      _x := Min(_x, (gScreenWidth div 2)-(FButtons[a].GetWidth div 2));

  lh := 0;
  {$IFDEF ENABLE_RENDER}
    lw := 0;
    if FHeader = nil then
      r_Render_GetLogoSize(lw, lh);
  {$ENDIF}
  hh := FButtons[High(FButtons)].GetHeight;

  if FHeader = nil then h := lh + hh * (1 + Length(FButtons)) + MAINMENU_SPACE * (Length(FButtons) - 1)
  else h := hh * (2 + Length(FButtons)) + MAINMENU_SPACE * (Length(FButtons) - 1);
  h := (gScreenHeight div 2) - (h div 2);

  if FHeader <> nil then with FHeader do
  begin
    FX := _x;
    FY := h;
  end;

  if FHeader = nil then Inc(h, lh)
  else Inc(h, hh*2);

  for a := 0 to High(FButtons) do
  begin
    if FButtons[a] <> nil then
    with FButtons[a] do
    begin
      FX := _x;
      FY := h;
    end;

    Inc(h, hh+MAINMENU_SPACE);
  end;

  Result := FButtons[High(FButtons)];
end;

procedure TGUIMainMenu.AddSpace;
begin
  SetLength(FButtons, Length(FButtons)+1);
  FButtons[High(FButtons)] := nil;
end;

constructor TGUIMainMenu.Create(BigFont: Boolean; Header: string);
begin
  inherited Create();

  FIndex := -1;
  FBigFont := BigFont;
  FCounter := MAINMENU_MARKERDELAY;

  if Header <> '' then
  begin
    FHeader := TGUILabel.Create(Header, BigFont);
    with FHeader do
    begin
      FColor := MAINMENU_HEADER_COLOR;
      FX := (gScreenWidth div 2)-(GetWidth div 2);
      FY := (gScreenHeight div 2)-(GetHeight div 2);
    end;
  end;
end;

destructor TGUIMainMenu.Destroy;
var
  a: Integer;
begin
  if FButtons <> nil then
    for a := 0 to High(FButtons) do
      FButtons[a].Free();

  FHeader.Free();

  inherited;
end;

procedure TGUIMainMenu.EnableButton(aName: string; e: Boolean);
var
  a: Integer;
begin
  if FButtons = nil then Exit;

  for a := 0 to High(FButtons) do
    if (FButtons[a] <> nil) and (FButtons[a].Name = aName) then
    begin
      if e then FButtons[a].FColor := MAINMENU_ITEMS_COLOR
      else FButtons[a].FColor := MAINMENU_UNACTIVEITEMS_COLOR;
      FButtons[a].Enabled := e;
      Break;
    end;
end;

function TGUIMainMenu.GetButton(aName: string): TGUITextButton;
var
  a: Integer;
begin
  Result := nil;

  if FButtons = nil then Exit;

  for a := 0 to High(FButtons) do
    if (FButtons[a] <> nil) and (FButtons[a].Name = aName) then
    begin
      Result := FButtons[a];
      Break;
    end;
end;

procedure TGUIMainMenu.OnMessage(var Msg: TMessage);
var
  ok: Boolean;
  a: Integer;
begin
  if not FEnabled then Exit;

  inherited;

  if FButtons = nil then Exit;

  ok := False;
  for a := 0 to High(FButtons) do
    if FButtons[a] <> nil then
    begin
      ok := True;
      Break;
    end;

  if not ok then Exit;

  case Msg.Msg of
    WM_KEYDOWN:
      case Msg.wParam of
        IK_UP, IK_KPUP, VK_UP, JOY0_UP, JOY1_UP, JOY2_UP, JOY3_UP:
        begin
          repeat
            Dec(FIndex);
            if FIndex < 0 then FIndex := High(FButtons);
          until FButtons[FIndex] <> nil;

          g_Sound_PlayEx(MENU_CHANGESOUND);
        end;
        IK_DOWN, IK_KPDOWN, VK_DOWN, JOY0_DOWN, JOY1_DOWN, JOY2_DOWN, JOY3_DOWN:
        begin
          repeat
            Inc(FIndex);
            if FIndex > High(FButtons) then FIndex := 0;
          until FButtons[FIndex] <> nil;

          g_Sound_PlayEx(MENU_CHANGESOUND);
        end;
        IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK: if (FIndex <> -1) and FButtons[FIndex].FEnabled then FButtons[FIndex].Click;
      end;
  end;
end;

procedure TGUIMainMenu.Update;
begin
  inherited;
  FCounter := (FCounter + 1) MOD (2 * MAINMENU_MARKERDELAY)
end;

{ TGUILabel }

constructor TGUILabel.Create(Text: string; BigFont: Boolean);
begin
  inherited Create();

  FBigFont := BigFont;
  FText := Text;
  FFixedLen := 0;
  FOnClickEvent := nil;
end;

procedure TGUILabel.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then Exit;

  inherited;

  case Msg.Msg of
    WM_KEYDOWN:
      case Msg.wParam of
        IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK: if @FOnClickEvent <> nil then FOnClickEvent();
      end;
  end;
end;

{ TGUIMenu }

function TGUIMenu.AddButton(Proc: Pointer; fText: string; _ShowWindow: string = ''): TGUITextButton;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUITextButton.Create(Proc, FBigFont, fText);
    with Control as TGUITextButton  do
    begin
      ShowWindow := _ShowWindow;
      FColor := MENU_ITEMSCTRL_COLOR;
    end;

    Text := nil;
    ControlType := TGUITextButton;

    Result := (Control as TGUITextButton);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

procedure TGUIMenu.AddLine(fText: string);
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    Control := nil;
  end;

  ReAlign();
end;

procedure TGUIMenu.AddText(fText: string; MaxWidth: Word);
var
  a, i: Integer;
  l: SSArray;
begin
  l := GetLines(fText, FBigFont, MaxWidth);

  if l = nil then Exit;

  for a := 0 to High(l) do
  begin
    i := NewItem();
    with FItems[i] do
    begin
      Text := TGUILabel.Create(l[a], FBigFont);
      if FYesNo then
      begin
        with Text do begin FColor := _RGB(255, 0, 0); end;
      end
      else
      begin
        with Text do begin FColor := MENU_ITEMSTEXT_COLOR; end;
      end;

      Control := nil;
    end;
  end;

  ReAlign();
end;

procedure TGUIMenu.AddSpace;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Text := nil;
    Control := nil;
  end;

  ReAlign();
end;

constructor TGUIMenu.Create(HeaderBigFont, ItemsBigFont: Boolean; Header: string);
begin
  inherited Create();

  FItems := nil;
  FIndex := -1;
  FBigFont := ItemsBigFont;
  FCounter := MENU_MARKERDELAY;
  FAlign := True;
  FYesNo := false;

  FHeader := TGUILabel.Create(Header, HeaderBigFont);
  with FHeader do
  begin
    FX := (gScreenWidth div 2)-(GetWidth div 2);
    FY := 0;
    FColor := MAINMENU_HEADER_COLOR;
  end;
end;

destructor TGUIMenu.Destroy;
var
  a: Integer;
begin
  if FItems <> nil then
    for a := 0 to High(FItems) do
      with FItems[a] do
      begin
        Text.Free();
        Control.Free();
      end;

  FItems := nil;

  FHeader.Free();

  inherited;
end;

function TGUIMenu.GetControl(aName: String): TGUIControl;
var
  a: Integer;
begin
  Result := nil;

  if FItems <> nil then
    for a := 0 to High(FItems) do
      if FItems[a].Control <> nil then
        if LowerCase(FItems[a].Control.Name) = LowerCase(aName) then
        begin
          Result := FItems[a].Control;
          Break;
        end;

  Assert(Result <> nil, 'GUI control "'+aName+'" not found!');
end;

function TGUIMenu.GetControlsText(aName: String): TGUILabel;
var
  a: Integer;
begin
  Result := nil;

  if FItems <> nil then
    for a := 0 to High(FItems) do
      if FItems[a].Control <> nil then
        if LowerCase(FItems[a].Control.Name) = LowerCase(aName) then
        begin
          Result := FItems[a].Text;
          Break;
        end;

  Assert(Result <> nil, 'GUI control''s text "'+aName+'" not found!');
end;

function TGUIMenu.NewItem: Integer;
begin
  SetLength(FItems, Length(FItems)+1);
  Result := High(FItems);
end;

procedure TGUIMenu.OnMessage(var Msg: TMessage);
var
  ok: Boolean;
  a, c: Integer;
begin
  if not FEnabled then Exit;

  inherited;

  if FItems = nil then Exit;

  ok := False;
  for a := 0 to High(FItems) do
    if FItems[a].Control <> nil then
    begin
      ok := True;
      Break;
    end;

  if not ok then Exit;

  if (Msg.Msg = WM_KEYDOWN) and (FIndex <> -1) and (FItems[FIndex].Control <> nil) and
     (FItems[FIndex].Control.WantActivationKey(Msg.wParam)) then
  begin
    FItems[FIndex].Control.OnMessage(Msg);
    g_Sound_PlayEx(MENU_CLICKSOUND);
    exit;
  end;

  case Msg.Msg of
    WM_KEYDOWN:
    begin
      case Msg.wParam of
        IK_UP, IK_KPUP, VK_UP,JOY0_UP, JOY1_UP, JOY2_UP, JOY3_UP:
        begin
          c := 0;
          repeat
            c := c+1;
            if c > Length(FItems) then
            begin
              FIndex := -1;
              Break;
            end;

            Dec(FIndex);
            if FIndex < 0 then FIndex := High(FItems);
          until (FItems[FIndex].Control <> nil) and
                (FItems[FIndex].Control.Enabled);

          FCounter := 0;

          g_Sound_PlayEx(MENU_CHANGESOUND);
        end;

        IK_DOWN, IK_KPDOWN, VK_DOWN, JOY0_DOWN, JOY1_DOWN, JOY2_DOWN, JOY3_DOWN:
        begin
          c := 0;
          repeat
            c := c+1;
            if c > Length(FItems) then
            begin
              FIndex := -1;
              Break;
            end;

            Inc(FIndex);
            if FIndex > High(FItems) then FIndex := 0;
          until (FItems[FIndex].Control <> nil) and
                (FItems[FIndex].Control.Enabled);

          FCounter := 0;

          g_Sound_PlayEx(MENU_CHANGESOUND);
        end;

        IK_LEFT, IK_RIGHT, IK_KPLEFT, IK_KPRIGHT, VK_LEFT, VK_RIGHT,
        JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT,
	JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
        begin
          if FIndex <> -1 then
            if FItems[FIndex].Control <> nil then
              FItems[FIndex].Control.OnMessage(Msg);
        end;
        IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
        begin
          if FIndex <> -1 then
          begin
            if FItems[FIndex].Control <> nil then FItems[FIndex].Control.OnMessage(Msg);
          end;
          g_Sound_PlayEx(MENU_CLICKSOUND);
        end;
        // dirty hacks
        IK_Y:
          if FYesNo and (length(FItems) > 1) then
          begin
            Msg.wParam := IK_RETURN; // to register keypress
            FIndex := High(FItems)-1;
            if FItems[FIndex].Control <> nil then FItems[FIndex].Control.OnMessage(Msg);
          end;
        IK_N:
          if FYesNo and (length(FItems) > 1) then
          begin
            Msg.wParam := IK_RETURN; // to register keypress
            FIndex := High(FItems);
            if FItems[FIndex].Control <> nil then FItems[FIndex].Control.OnMessage(Msg);
          end;
      end;
    end;
  end;
end;

procedure TGUIMenu.ReAlign();
  var
    {$IFDEF ENABLE_RENDER}
      fw, fh: Integer;
    {$ENDIF}
    a, tx, cx, w, h: Integer;
    cww: array of Integer; // cached widths
    maxcww: Integer;
begin
  if FItems = nil then Exit;

  SetLength(cww, length(FItems));
  maxcww := 0;
  for a := 0 to High(FItems) do
  begin
    if FItems[a].Text <> nil then
    begin
      cww[a] := FItems[a].Text.GetWidth;
      if maxcww < cww[a] then maxcww := cww[a];
    end;
  end;

  if not FAlign then
  begin
    tx := FLeft;
  end
  else
  begin
    tx := gScreenWidth;
    for a := 0 to High(FItems) do
    begin
      w := 0;
      if FItems[a].Text <> nil then w := FItems[a].Text.GetWidth;
      if FItems[a].Control <> nil then
      begin
        w := w+MENU_HSPACE;
             if FItems[a].ControlType = TGUILabel then w := w+(FItems[a].Control as TGUILabel).GetWidth
        else if FItems[a].ControlType = TGUITextButton then w := w+(FItems[a].Control as TGUITextButton).GetWidth
        else if FItems[a].ControlType = TGUIScroll then w := w+(FItems[a].Control as TGUIScroll).GetWidth
        else if FItems[a].ControlType = TGUISwitch then w := w+(FItems[a].Control as TGUISwitch).GetWidth
        else if FItems[a].ControlType = TGUIEdit then w := w+(FItems[a].Control as TGUIEdit).GetWidth
        else if FItems[a].ControlType = TGUIKeyRead then w := w+(FItems[a].Control as TGUIKeyRead).GetWidth
        else if FItems[a].ControlType = TGUIKeyRead2 then w := w+(FItems[a].Control as TGUIKeyRead2).GetWidth
        else if FItems[a].ControlType = TGUIListBox then w := w+(FItems[a].Control as TGUIListBox).GetWidth
        else if FItems[a].ControlType = TGUIFileListBox then w := w+(FItems[a].Control as TGUIFileListBox).GetWidth
        else if FItems[a].ControlType = TGUIMemo then w := w+(FItems[a].Control as TGUIMemo).GetWidth;
      end;
      tx := Min(tx, (gScreenWidth div 2)-(w div 2));
    end;
  end;

  cx := 0;
  for a := 0 to High(FItems) do
  begin
    with FItems[a] do
    begin
      if (Text <> nil) and (Control = nil) then Continue;
      w := 0;
      if Text <> nil then w := tx+Text.GetWidth;
      if w > cx then cx := w;
    end;
  end;

  cx := cx+MENU_HSPACE;

  h := FHeader.GetHeight*2+MENU_VSPACE*(Length(FItems)-1);

  for a := 0 to High(FItems) do
  begin
    with FItems[a] do
    begin
      if (ControlType = TGUIListBox) or (ControlType = TGUIFileListBox) then
        h := h+(FItems[a].Control as TGUIListBox).GetHeight()
      else
      begin
        {$IFDEF ENABLE_RENDER}
          r_Render_GetMaxFontSize(FBigFont, fw, fh);
          h := h + fh;
        {$ENDIF}
      end;
    end;
  end;

  h := (gScreenHeight div 2)-(h div 2);

  with FHeader do
  begin
    FX := (gScreenWidth div 2)-(GetWidth div 2);
    FY := h;

    Inc(h, GetHeight*2);
  end;

  for a := 0 to High(FItems) do
  begin
    with FItems[a] do
    begin
      if Text <> nil then
      begin
        with Text do
        begin
          FX := tx;
          FY := h;
        end;
        //HACK!
        if Text.RightAlign and (length(cww) > a) then
        begin
          //Text.FX := Text.FX+maxcww;
          Text.FMaxWidth := maxcww;
        end;
      end;

      if Control <> nil then
      begin
        with Control do
        begin
          if Text <> nil then
          begin
            FX := cx;
            FY := h;
          end
          else
          begin
            FX := tx;
            FY := h;
          end;
        end;
      end;

           if (ControlType = TGUIListBox) or (ControlType = TGUIFileListBox) then Inc(h, (Control as TGUIListBox).GetHeight+MENU_VSPACE)
      else if ControlType = TGUIMemo then Inc(h, (Control as TGUIMemo).GetHeight+MENU_VSPACE)
      else
      begin
        {$IFDEF ENABLE_RENDER}
          r_Render_GetMaxFontSize(FBigFont, fw, fh);
          h := h + fh + MENU_VSPACE;
        {$ELSE}
          h := h + MENU_VSPACE;
        {$ENDIF}
      end;
    end;
  end;

  // another ugly hack
  if FYesNo and (length(FItems) > 1) then
  begin
    w := -1;
    for a := High(FItems)-1 to High(FItems) do
    begin
      if (FItems[a].Control <> nil) and (FItems[a].ControlType = TGUITextButton) then
      begin
        cx := (FItems[a].Control as TGUITextButton).GetWidth;
        if cx > w then w := cx;
      end;
    end;
    if w > 0 then
    begin
      for a := High(FItems)-1 to High(FItems) do
      begin
        if (FItems[a].Control <> nil) and (FItems[a].ControlType = TGUITextButton) then
        begin
          FItems[a].Control.FX := (gScreenWidth-w) div 2;
        end;
      end;
    end;
  end;
end;

function TGUIMenu.AddScroll(fText: string): TGUIScroll;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIScroll.Create();

    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUIScroll;

    Result := (Control as TGUIScroll);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddSwitch(fText: string): TGUISwitch;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUISwitch.Create(FBigFont);
   (Control as TGUISwitch).FColor := MENU_ITEMSCTRL_COLOR;

    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUISwitch;

    Result := (Control as TGUISwitch);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddEdit(fText: string): TGUIEdit;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIEdit.Create(FBigFont);
    with Control as TGUIEdit do
    begin
      FWindow := Self.FWindow;
      FColor := MENU_ITEMSCTRL_COLOR;
    end;

    if fText = '' then Text := nil else
    begin
      Text := TGUILabel.Create(fText, FBigFont);
      Text.FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUIEdit;

    Result := (Control as TGUIEdit);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

procedure TGUIMenu.Update;
var
  a: Integer;
begin
  inherited;

  if FCounter = 0 then FCounter := MENU_MARKERDELAY else Dec(FCounter);

  if FItems <> nil then
    for a := 0 to High(FItems) do
      if FItems[a].Control <> nil then
        (FItems[a].Control as FItems[a].ControlType).Update;
end;

function TGUIMenu.AddKeyRead(fText: string): TGUIKeyRead;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIKeyRead.Create(FBigFont);
    with Control as TGUIKeyRead do
    begin
      FWindow := Self.FWindow;
      FColor := MENU_ITEMSCTRL_COLOR;
    end;

    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUIKeyRead;

    Result := (Control as TGUIKeyRead);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddKeyRead2(fText: string): TGUIKeyRead2;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIKeyRead2.Create(FBigFont);
    with Control as TGUIKeyRead2 do
    begin
      FWindow := Self.FWindow;
      FColor := MENU_ITEMSCTRL_COLOR;
    end;

    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSCTRL_COLOR; //MENU_ITEMSTEXT_COLOR;
      RightAlign := true;
    end;

    ControlType := TGUIKeyRead2;

    Result := (Control as TGUIKeyRead2);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddList(fText: string; Width, Height: Word): TGUIListBox;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIListBox.Create(FBigFont, Width, Height);
    with Control as TGUIListBox do
    begin
      FWindow := Self.FWindow;
      FActiveColor := MENU_ITEMSCTRL_COLOR;
      FUnActiveColor := MENU_ITEMSTEXT_COLOR;
    end;

    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUIListBox;

    Result := (Control as TGUIListBox);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddFileList(fText: string; Width, Height: Word): TGUIFileListBox;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIFileListBox.Create(FBigFont, Width, Height);
    with Control as TGUIFileListBox do
    begin
      FWindow := Self.FWindow;
      FActiveColor := MENU_ITEMSCTRL_COLOR;
      FUnActiveColor := MENU_ITEMSTEXT_COLOR;
    end;

    if fText = '' then Text := nil else
    begin
      Text := TGUILabel.Create(fText, FBigFont);
      Text.FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUIFileListBox;

    Result := (Control as TGUIFileListBox);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddLabel(fText: string): TGUILabel;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUILabel.Create('', FBigFont);
    with Control as TGUILabel do
    begin
      FWindow := Self.FWindow;
      FColor := MENU_ITEMSCTRL_COLOR;
    end;

    Text := TGUILabel.Create(fText, FBigFont);
    with Text do
    begin
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUILabel;

    Result := (Control as TGUILabel);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

function TGUIMenu.AddMemo(fText: string; Width, Height: Word): TGUIMemo;
var
  i: Integer;
begin
  i := NewItem();
  with FItems[i] do
  begin
    Control := TGUIMemo.Create(FBigFont, Width, Height);
    with Control as TGUIMemo do
    begin
      FWindow := Self.FWindow;
      FColor := MENU_ITEMSTEXT_COLOR;
    end;

    if fText = '' then Text := nil else
    begin
      Text := TGUILabel.Create(fText, FBigFont);
      Text.FColor := MENU_ITEMSTEXT_COLOR;
    end;

    ControlType := TGUIMemo;

    Result := (Control as TGUIMemo);
  end;

  if FIndex = -1 then FIndex := i;

  ReAlign();
end;

procedure TGUIMenu.UpdateIndex();
var
  res: Boolean;
begin
  res := True;

  while res do
  begin
    if (FIndex < 0) or (FIndex > High(FItems)) then
      begin
        FIndex := -1;
        res := False;
      end
    else
      if FItems[FIndex].Control.Enabled then
        res := False
      else
        Inc(FIndex);
  end;
end;

{ TGUIScroll }

constructor TGUIScroll.Create;
begin
  inherited Create();

  FMax := 0;
  FOnChangeEvent := nil;
end;

procedure TGUIScroll.FSetValue(a: Integer);
begin
  if a > FMax then FValue := FMax else FValue := a;
end;

procedure TGUIScroll.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then Exit;

  inherited;

  case Msg.Msg of
    WM_KEYDOWN:
    begin
      case Msg.wParam of
        IK_LEFT, IK_KPLEFT, VK_LEFT, JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT:
          if FValue > 0 then
          begin
            Dec(FValue);
            g_Sound_PlayEx(SCROLL_SUBSOUND);
            if @FOnChangeEvent <> nil then FOnChangeEvent(Self);
          end;
        IK_RIGHT, IK_KPRIGHT, VK_RIGHT, JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
          if FValue < FMax then
          begin
            Inc(FValue);
            g_Sound_PlayEx(SCROLL_ADDSOUND);
            if @FOnChangeEvent <> nil then FOnChangeEvent(Self);
          end;
      end;
    end;
  end;
end;

procedure TGUIScroll.Update;
begin
  inherited;

end;

{ TGUISwitch }

procedure TGUISwitch.AddItem(Item: string);
begin
  SetLength(FItems, Length(FItems)+1);
  FItems[High(FItems)] := Item;

  if FIndex = -1 then FIndex := 0;
end;

constructor TGUISwitch.Create(BigFont: Boolean);
begin
  inherited Create();

  FIndex := -1;

  FBigFont := BigFont;
end;

function TGUISwitch.GetText: string;
begin
  if FIndex <> -1 then Result := FItems[FIndex]
  else Result := '';
end;

procedure TGUISwitch.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then Exit;

  inherited;

  if FItems = nil then Exit;

  case Msg.Msg of
    WM_KEYDOWN:
      case Msg.wParam of
        IK_RETURN, IK_RIGHT, IK_KPRETURN, IK_KPRIGHT, VK_FIRE, VK_OPEN, VK_RIGHT,
        JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT,
        JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
        begin
          if FIndex < High(FItems) then
            Inc(FIndex)
          else
            FIndex := 0;

          g_Sound_PlayEx(SCROLL_ADDSOUND);

          if @FOnChangeEvent <> nil then
            FOnChangeEvent(Self);
        end;

      IK_LEFT, IK_KPLEFT, VK_LEFT,
      JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT:
        begin
          if FIndex > 0 then
            Dec(FIndex)
          else
            FIndex := High(FItems);

          g_Sound_PlayEx(SCROLL_SUBSOUND);

          if @FOnChangeEvent <> nil then
            FOnChangeEvent(Self);
        end;
    end;
  end;
end;

procedure TGUISwitch.Update;
begin
  inherited;

end;

{ TGUIEdit }

constructor TGUIEdit.Create(BigFont: Boolean);
begin
  inherited Create();

  FBigFont := BigFont;
  FMaxLength := 0;
  FWidth := 0;
  FInvalid := false;
end;

procedure TGUIEdit.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then Exit;

  inherited;

  with Msg do
    case Msg of
      WM_CHAR:
        if FOnlyDigits then
        begin
          if (wParam in [48..57]) and (Chr(wParam) <> '`') then
            if Length(Text) < FMaxLength then
            begin
              Insert(Chr(wParam), FText, FCaretPos + 1);
              Inc(FCaretPos);
            end;
        end
        else
        begin
          if (wParam in [32..255]) and (Chr(wParam) <> '`') then
            if Length(Text) < FMaxLength then
            begin
              Insert(Chr(wParam), FText, FCaretPos + 1);
              Inc(FCaretPos);
            end;
        end;
      WM_KEYDOWN:
        case wParam of
          IK_BACKSPACE:
          begin
            Delete(FText, FCaretPos, 1);
            if FCaretPos > 0 then Dec(FCaretPos);
          end;
          IK_DELETE: Delete(FText, FCaretPos + 1, 1);
          IK_END, IK_KPEND: FCaretPos := Length(FText);
          IK_HOME, IK_KPHOME: FCaretPos := 0;
          IK_LEFT, IK_KPLEFT, VK_LEFT, JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT: if FCaretPos > 0 then Dec(FCaretPos);
          IK_RIGHT, IK_KPRIGHT, VK_RIGHT, JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT: if FCaretPos < Length(FText) then Inc(FCaretPos);
          IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
            with FWindow do
            begin
              if FActiveControl <> Self then
              begin
                SetActive(Self);
                if @FOnEnterEvent <> nil then FOnEnterEvent(Self);
              end
              else
              begin
                if FDefControl <> '' then SetActive(GetControl(FDefControl))
                else SetActive(nil);
                if @FOnChangeEvent <> nil then FOnChangeEvent(Self);
              end;
            end;
        end;
    end;

  g_GUIGrabInput := (@FOnEnterEvent = nil) and (FWindow.FActiveControl = Self);

  {$IFDEF ENABLE_TOUCH}
    sys_ShowKeyboard(g_GUIGrabInput)
  {$ENDIF}
end;

procedure TGUIEdit.SetText(Text: string);
begin
  if Length(Text) > FMaxLength then SetLength(Text, FMaxLength);
  FText := Text;
  FCaretPos := Length(FText);
end;

procedure TGUIEdit.Update;
begin
  inherited;
end;

{ TGUIKeyRead }

constructor TGUIKeyRead.Create(BigFont: Boolean);
begin
  inherited Create();
  FKey := 0;
  FIsQuery := false;
  FBigFont := BigFont;
end;

function TGUIKeyRead.WantActivationKey (key: LongInt): Boolean;
begin
  result :=
    (key = IK_BACKSPACE) or
    false; // oops
end;

procedure TGUIKeyRead.OnMessage(var Msg: TMessage);
  procedure actDefCtl ();
  begin
    with FWindow do
      if FDefControl <> '' then
        SetActive(GetControl(FDefControl))
      else
        SetActive(nil);
  end;

begin
  inherited;

  if not FEnabled then
    Exit;

  with Msg do
    case Msg of
      WM_KEYDOWN:
        if not FIsQuery then
        begin
          case wParam of
            IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
              begin
                with FWindow do
                  if FActiveControl <> Self then
                    SetActive(Self);
                FIsQuery := True;
              end;
            IK_BACKSPACE: // clear keybinding if we aren't waiting for a key
              begin
                FKey := 0;
                actDefCtl();
              end;
          else
            FIsQuery := False;
            actDefCtl();
          end;
        end
        else
        begin
          case wParam of
            VK_FIRSTKEY..VK_LASTKEY: // do not allow to bind virtual keys
              begin
                FIsQuery := False;
                actDefCtl();
              end;
          else
            if (e_KeyNames[wParam] <> '') and not g_Console_MatchBind(wParam, 'togglemenu') then
              FKey := wParam;
            FIsQuery := False;
            actDefCtl();
          end
        end;
    end;

  g_GUIGrabInput := FIsQuery
end;

{ TGUIKeyRead2 }

constructor TGUIKeyRead2.Create(BigFont: Boolean);
  {$IFDEF ENABLE_RENDER}
    var a: Byte; w, h: Integer;
  {$ENDIF}
begin
  inherited Create();

  FKey0 := 0;
  FKey1 := 0;
  FKeyIdx := 0;
  FIsQuery := False;

  FBigFont := BigFont;

  FMaxKeyNameWdt := 0;

  {$IFDEF ENABLE_RENDER}
    for a := 0 to 255 do
    begin
      r_Render_GetStringSize(BigFont, e_KeyNames[a], w, h);
      FMaxKeyNameWdt := Max(FMaxKeyNameWdt, w);
    end;
    FMaxKeyNameWdt := FMaxKeyNameWdt-(FMaxKeyNameWdt div 3);
    r_Render_GetStringSize(BigFont, KEYREAD_QUERY, w, h);
    if w > FMaxKeyNameWdt then FMaxKeyNameWdt := w;
    r_Render_GetStringSize(BigFont, KEYREAD_CLEAR, w, h);
    if w > FMaxKeyNameWdt then FMaxKeyNameWdt := w;
  {$ENDIF}
end;

function TGUIKeyRead2.WantActivationKey (key: LongInt): Boolean;
begin
  case key of
    IK_BACKSPACE, IK_LEFT, IK_RIGHT, IK_KPLEFT, IK_KPRIGHT, VK_LEFT, VK_RIGHT,
    JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT,
    JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
      result := True
  else
      result := False
  end
end;

procedure TGUIKeyRead2.OnMessage(var Msg: TMessage);
  procedure actDefCtl ();
  begin
    with FWindow do
      if FDefControl <> '' then
        SetActive(GetControl(FDefControl))
      else
        SetActive(nil);
  end;

begin
  inherited;

  if not FEnabled then
    Exit;

  with Msg do
    case Msg of
      WM_KEYDOWN:
        if not FIsQuery then
        begin
          case wParam of
            IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
              begin
                with FWindow do
                  if FActiveControl <> Self then
                    SetActive(Self);
                FIsQuery := True;
              end;
            IK_BACKSPACE: // clear keybinding if we aren't waiting for a key
              begin
                if (FKeyIdx = 0) then FKey0 := 0 else FKey1 := 0;
                actDefCtl();
              end;
            IK_LEFT, IK_KPLEFT, VK_LEFT, JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT:
              begin
                FKeyIdx := 0;
                actDefCtl();
              end;
            IK_RIGHT, IK_KPRIGHT, VK_RIGHT, JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
              begin
                FKeyIdx := 1;
                actDefCtl();
              end;
          else
            FIsQuery := False;
            actDefCtl();
          end;
        end
        else
        begin
          case wParam of
            VK_FIRSTKEY..VK_LASTKEY: // do not allow to bind virtual keys
              begin
                FIsQuery := False;
                actDefCtl();
              end;
          else
            if (e_KeyNames[wParam] <> '') and not g_Console_MatchBind(wParam, 'togglemenu') then
            begin
              if (FKeyIdx = 0) then FKey0 := wParam else FKey1 := wParam;
            end;
            FIsQuery := False;
            actDefCtl()
          end
        end;
    end;

  g_GUIGrabInput := FIsQuery
end;


{ TGUIModelView }

constructor TGUIModelView.Create;
begin
  inherited Create();

  FModel := nil;
end;

destructor TGUIModelView.Destroy;
begin
  FModel.Free();

  inherited;
end;

procedure TGUIModelView.NextAnim();
begin
  if FModel = nil then
    Exit;

  if FModel.Animation < A_PAIN then
    FModel.ChangeAnimation(FModel.Animation+1, True)
  else
    FModel.ChangeAnimation(A_STAND, True);
end;

procedure TGUIModelView.NextWeapon();
begin
  if FModel = nil then
    Exit;

  if FModel.Weapon < WP_LAST then
    FModel.SetWeapon(FModel.Weapon+1)
  else
    FModel.SetWeapon(WEAPON_KASTET);
end;

procedure TGUIModelView.OnMessage(var Msg: TMessage);
begin
  inherited;

end;

procedure TGUIModelView.SetColor(Red, Green, Blue: Byte);
begin
  if FModel <> nil then FModel.SetColor(Red, Green, Blue);
end;

procedure TGUIModelView.SetModel(ModelName: string);
begin
  FModel.Free();

  FModel := g_PlayerModel_Get(ModelName);
end;

procedure TGUIModelView.Update;
begin
  inherited;

  a := not a;
  if a then Exit;

  if FModel <> nil then FModel.Update;
end;

{ TGUIMapPreview }

constructor TGUIMapPreview.Create();
begin
  inherited Create();
  ClearMap;
end;

destructor TGUIMapPreview.Destroy();
begin
  ClearMap;
  inherited;
end;

procedure TGUIMapPreview.OnMessage(var Msg: TMessage);
begin
  inherited;

end;

procedure TGUIMapPreview.SetMap(Res: string);
var
  WAD: TWADFile;
  panlist: TDynField;
  pan: TDynRecord;
  //header: TMapHeaderRec_1;
  FileName: string;
  Data: Pointer;
  Len: Integer;
  rX, rY: Single;
  map: TDynRecord = nil;
begin
  FMapSize.X := 0;
  FMapSize.Y := 0;
  FScale := 0.0;
  FMapData := nil;

  FileName := g_ExtractWadName(Res);

  WAD := TWADFile.Create();
  if not WAD.ReadFile(FileName) then
  begin
    WAD.Free();
    Exit;
  end;

  //k8: ignores path again
  if not WAD.GetMapResource(g_ExtractFileName(Res), Data, Len) then
  begin
    WAD.Free();
    Exit;
  end;

  WAD.Free();

  try
    map := g_Map_ParseMap(Data, Len);
  except
    FreeMem(Data);
    map.Free();
    //raise;
    exit;
  end;

  FreeMem(Data);

  if (map = nil) then exit;

  try
    panlist := map.field['panel'];
    //header := GetMapHeader(map);

    FMapSize.X := map.Width div 16;
    FMapSize.Y := map.Height div 16;

    rX := Ceil(map.Width / (MAPPREVIEW_WIDTH*256.0));
    rY := Ceil(map.Height / (MAPPREVIEW_HEIGHT*256.0));
    FScale := max(rX, rY);

    FMapData := nil;

    if (panlist <> nil) then
    begin
      for pan in panlist do
      begin
        if (pan.PanelType and (PANEL_WALL or PANEL_CLOSEDOOR or
                                             PANEL_STEP or PANEL_WATER or
                                             PANEL_ACID1 or PANEL_ACID2)) <> 0 then
        begin
          SetLength(FMapData, Length(FMapData)+1);
          with FMapData[High(FMapData)] do
          begin
            X1 := pan.X div 16;
            Y1 := pan.Y div 16;

            X2 := (pan.X + pan.Width) div 16;
            Y2 := (pan.Y + pan.Height) div 16;

            X1 := Trunc(X1/FScale + 0.5);
            Y1 := Trunc(Y1/FScale + 0.5);
            X2 := Trunc(X2/FScale + 0.5);
            Y2 := Trunc(Y2/FScale + 0.5);

            if (X1 <> X2) or (Y1 <> Y2) then
            begin
              if X1 = X2 then
                X2 := X2 + 1;
              if Y1 = Y2 then
                Y2 := Y2 + 1;
            end;

            PanelType := pan.PanelType;
          end;
        end;
      end;
    end;
  finally
    //writeln('freeing map');
    map.Free();
  end;
end;

procedure TGUIMapPreview.ClearMap();
begin
  SetLength(FMapData, 0);
  FMapData := nil;
  FMapSize.X := 0;
  FMapSize.Y := 0;
  FScale := 0.0;
end;

procedure TGUIMapPreview.Update();
begin
  inherited;

end;

function TGUIMapPreview.GetScaleStr(): String;
begin
  if FScale > 0.0 then
    begin
      Result := FloatToStrF(FScale*16.0, ffFixed, 3, 3);
      while (Result[Length(Result)] = '0') do
        Delete(Result, Length(Result), 1);
      if (Result[Length(Result)] = ',') or (Result[Length(Result)] = '.') then
        Delete(Result, Length(Result), 1);
      Result := '1 : ' + Result;
    end
  else
    Result := '';
end;

{ TGUIListBox }

procedure TGUIListBox.AddItem(Item: string);
begin
  SetLength(FItems, Length(FItems)+1);
  FItems[High(FItems)] := Item;

  if FSort then g_gui.Sort(FItems);
end;

function TGUIListBox.ItemExists (item: String): Boolean;
  var i: Integer;
begin
  i := 0;
  while (i <= High(FItems)) and (FItems[i] <> item) do Inc(i);
  result := i <= High(FItems)
end;

procedure TGUIListBox.Clear;
begin
  FItems := nil;

  FStartLine := 0;
  FIndex := -1;
end;

constructor TGUIListBox.Create(BigFont: Boolean; Width, Height: Word);
begin
  inherited Create();

  FBigFont := BigFont;
  FWidth := Width;
  FHeight := Height;
  FIndex := -1;
  FOnChangeEvent := nil;
  FDrawBack := True;
  FDrawScroll := True;
end;

procedure TGUIListBox.OnMessage(var Msg: TMessage);
var
  a: Integer;
begin
  if not FEnabled then Exit;

  inherited;

  if FItems = nil then Exit;

  with Msg do
    case Msg of
      WM_KEYDOWN:
        case wParam of
          IK_HOME, IK_KPHOME:
          begin
            FIndex := 0;
            FStartLine := 0;
          end;
          IK_END, IK_KPEND:
          begin
            FIndex := High(FItems);
            FStartLine := Max(High(FItems)-FHeight+1, 0);
          end;
          IK_UP, IK_LEFT, IK_KPUP, IK_KPLEFT, VK_LEFT, JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT:
            if FIndex > 0 then
            begin
              Dec(FIndex);
              if FIndex < FStartLine then Dec(FStartLine);
              if @FOnChangeEvent <> nil then FOnChangeEvent(Self);
            end;
          IK_DOWN, IK_RIGHT, IK_KPDOWN, IK_KPRIGHT, VK_RIGHT, JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
            if FIndex < High(FItems) then
            begin
              Inc(FIndex);
              if FIndex > FStartLine+FHeight-1 then Inc(FStartLine);
              if @FOnChangeEvent <> nil then FOnChangeEvent(Self);
            end;
          IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
            with FWindow do
            begin
              if FActiveControl <> Self then SetActive(Self)
              else
                if FDefControl <> '' then SetActive(GetControl(FDefControl))
                else SetActive(nil);
            end;
        end;
      WM_CHAR:
        for a := 0 to High(FItems) do
          if (Length(FItems[a]) > 0) and (LowerCase(FItems[a][1]) = LowerCase(Chr(wParam))) then
          begin
            FIndex := a;
            FStartLine := Min(Max(FIndex-1, 0), Length(FItems)-FHeight);
            if @FOnChangeEvent <> nil then FOnChangeEvent(Self);
            Break;
          end;
    end;
end;

function TGUIListBox.SelectedItem(): String;
begin
  Result := '';

  if (FIndex < 0) or (FItems = nil) or
     (FIndex > High(FItems)) then
    Exit;

  Result := FItems[FIndex];
end;

procedure TGUIListBox.FSetItems(Items: SSArray);
begin
  if FItems <> nil then
    FItems := nil;

  FItems := Items;

  FStartLine := 0;
  FIndex := -1;

  if FSort then g_gui.Sort(FItems);
end;

procedure TGUIListBox.SelectItem(Item: String);
var
  a: Integer;
begin
  if FItems = nil then
    Exit;

  FIndex := 0;
  Item := LowerCase(Item);

  for a := 0 to High(FItems) do
    if LowerCase(FItems[a]) = Item then
    begin
      FIndex := a;
      Break;
    end;

  if FIndex < FHeight then
    FStartLine := 0
  else
    FStartLine := Min(FIndex, Length(FItems)-FHeight);
end;

procedure TGUIListBox.FSetIndex(aIndex: Integer);
begin
  if FItems = nil then
    Exit;

  if (aIndex < 0) or (aIndex > High(FItems)) then
    Exit;

  FIndex := aIndex;

  if FIndex <= FHeight then
    FStartLine := 0
  else
    FStartLine := Min(FIndex, Length(FItems)-FHeight);
end;

{ TGUIFileListBox }

procedure TGUIFileListBox.OnMessage(var Msg: TMessage);
var
  a, b: Integer; s: AnsiString;
begin
  if not FEnabled then
    Exit;

  if FItems = nil then
    Exit;

  with Msg do
    case Msg of
      WM_KEYDOWN:
        case wParam of
          IK_HOME, IK_KPHOME:
            begin
              FIndex := 0;
              FStartLine := 0;
              if @FOnChangeEvent <> nil then
                FOnChangeEvent(Self);
            end;

          IK_END, IK_KPEND:
            begin
              FIndex := High(FItems);
              FStartLine := Max(High(FItems)-FHeight+1, 0);
              if @FOnChangeEvent <> nil then
                FOnChangeEvent(Self);
            end;

          IK_PAGEUP, IK_KPPAGEUP:
            begin
              if FIndex > FHeight then
                FIndex := FIndex-FHeight
              else
                FIndex := 0;

              if FStartLine > FHeight then
                FStartLine := FStartLine-FHeight
              else
                FStartLine := 0;
            end;

          IK_PAGEDN, IK_KPPAGEDN:
            begin
              if FIndex < High(FItems)-FHeight then
                FIndex := FIndex+FHeight
              else
                FIndex := High(FItems);

              if FStartLine < High(FItems)-FHeight then
                FStartLine := FStartLine+FHeight
              else
                FStartLine := High(FItems)-FHeight+1;
            end;

          IK_UP, IK_LEFT, IK_KPUP, IK_KPLEFT, VK_UP, VK_LEFT, JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT:
            if FIndex > 0 then
            begin
              Dec(FIndex);
              if FIndex < FStartLine then
                Dec(FStartLine);
              if @FOnChangeEvent <> nil then
                FOnChangeEvent(Self);
            end;

          IK_DOWN, IK_RIGHT, IK_KPDOWN, IK_KPRIGHT, VK_DOWN, VK_RIGHT, JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
            if FIndex < High(FItems) then
            begin
              Inc(FIndex);
              if FIndex > FStartLine+FHeight-1 then
                Inc(FStartLine);
              if @FOnChangeEvent <> nil then
                FOnChangeEvent(Self);
            end;

          IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
            with FWindow do
            begin
              if FActiveControl <> Self then
                SetActive(Self)
              else
                begin
                  if FItems[FIndex][1] = #29 then // �����
                  begin
                    if FItems[FIndex] = #29 + '..' then
                    begin
                      if gDebugMode then e_LogWritefln('TGUIFileListBox: Upper dir "%s" -> "%s"', [FSubPath, e_UpperDir(FSubPath)]);
                      FSubPath := e_UpperDir(FSubPath)
                    end
                    else
                    begin
                      s := Copy(AnsiString(FItems[FIndex]), 2);
                      if gDebugMode then  e_LogWritefln('TGUIFileListBox: Enter dir "%s" -> "%s"', [FSubPath, e_CatPath(FSubPath, s)]);
                      FSubPath := e_CatPath(FSubPath, s);
                    end;
                    ScanDirs;
                    FIndex := 0;
                    Exit;
                  end;

                  if FDefControl <> '' then
                    SetActive(GetControl(FDefControl))
                  else
                    SetActive(nil);
                end;
            end;
        end;

      WM_CHAR:
        for b := FIndex + 1 to High(FItems) + FIndex do
        begin
          a := b mod Length(FItems);
          if ( (Length(FItems[a]) > 0) and
               (LowerCase(FItems[a][1]) = LowerCase(Chr(wParam))) ) or
             ( (Length(FItems[a]) > 1) and
               (FItems[a][1] = #29) and // �����
               (LowerCase(FItems[a][2]) = LowerCase(Chr(wParam))) ) then
          begin
            FIndex := a;
            FStartLine := Min(Max(FIndex-1, 0), Length(FItems)-FHeight);
            if @FOnChangeEvent <> nil then
              FOnChangeEvent(Self);
            Break;
          end;
        end;
    end;
end;

procedure TGUIFileListBox.ScanDirs;
  var i, j: Integer; path: AnsiString; SR: TSearchRec; sm, sc: String;
begin
  Clear;

  i := High(FBaseList);
  while i >= 0 do
  begin
    path := e_CatPath(FBaseList[i], FSubPath);
    if FDirs then
    begin
      if FindFirst(path + '/' + '*', faDirectory, SR) = 0 then
      begin
        repeat
          if LongBool(SR.Attr and faDirectory) then
            if (SR.Name <> '.') and ((FSubPath <> '') or (SR.Name <> '..')) then
              if Self.ItemExists(#1 + SR.Name) = false then
                Self.AddItem(#1 + SR.Name)
        until FindNext(SR) <> 0
      end;
      FindClose(SR)
    end;
    Dec(i)
  end;

  i := High(FBaseList);
  while i >= 0 do
  begin
    path := e_CatPath(FBaseList[i], FSubPath);
    sm := FFileMask;
    while sm <> '' do
    begin
      j := Pos('|', sm);
      if j = 0 then
        j := length(sm) + 1;
      sc := Copy(sm, 1, j - 1);
      Delete(sm, 1, j);
      if FindFirst(path + '/' + sc, faAnyFile, SR) = 0 then
      begin
        repeat
          if Self.ItemExists(SR.Name) = false then
            AddItem(SR.Name)
        until FindNext(SR) <> 0
      end;
      FindClose(SR)
    end;
    Dec(i)
  end;

  for i := 0 to High(FItems) do
    if FItems[i][1] = #1 then
      FItems[i][1] := #29;
end;

procedure TGUIFileListBox.SetBase (dirs: SSArray; path: String = '');
begin
  FBaseList := dirs;
  FSubPath := path;
  ScanDirs
end;

function TGUIFileListBox.SelectedItem (): String;
  var s: AnsiString;
begin
  result := '';
  if (FIndex >= 0) and (FIndex <= High(FItems)) and (FItems[FIndex][1] <> '/') and (FItems[FIndex][1] <> '\') then
  begin
    s := e_CatPath(FSubPath, FItems[FIndex]);
    if e_FindResource(FBaseList, s) = true then
      result := ExpandFileName(s)
  end;
  if gDebugMode then e_LogWritefln('TGUIFileListBox.SelectedItem -> "%s"', [result]);
end;

procedure TGUIFileListBox.UpdateFileList();
var
  fn: String;
begin
  if (FIndex = -1) or (FItems = nil) or
     (FIndex > High(FItems)) or
     (FItems[FIndex][1] = '/') or
     (FItems[FIndex][1] = '\') then
    fn := ''
  else
    fn := FItems[FIndex];

//  OpenDir(FPath);
  ScanDirs;

  if fn <> '' then
    SelectItem(fn);
end;

{ TGUIMemo }

procedure TGUIMemo.Clear;
begin
  FLines := nil;
  FStartLine := 0;
end;

constructor TGUIMemo.Create(BigFont: Boolean; Width, Height: Word);
begin
  inherited Create();

  FBigFont := BigFont;
  FWidth := Width;
  FHeight := Height;
  FDrawBack := True;
  FDrawScroll := True;
end;

procedure TGUIMemo.OnMessage(var Msg: TMessage);
begin
  if not FEnabled then Exit;

  inherited;

  if FLines = nil then Exit;

  with Msg do
    case Msg of
      WM_KEYDOWN:
        case wParam of
          IK_UP, IK_LEFT, IK_KPUP, IK_KPLEFT, VK_UP, VK_LEFT, JOY0_LEFT, JOY1_LEFT, JOY2_LEFT, JOY3_LEFT:
            if FStartLine > 0 then
              Dec(FStartLine);
          IK_DOWN, IK_RIGHT, IK_KPDOWN, IK_KPRIGHT, VK_DOWN, VK_RIGHT, JOY0_RIGHT, JOY1_RIGHT, JOY2_RIGHT, JOY3_RIGHT:
            if FStartLine < Length(FLines)-FHeight then
              Inc(FStartLine);
          IK_RETURN, IK_KPRETURN, VK_FIRE, VK_OPEN, JOY0_ATTACK, JOY1_ATTACK, JOY2_ATTACK, JOY3_ATTACK:
            with FWindow do
            begin
              if FActiveControl <> Self then
              begin
                SetActive(Self);
                {FStartLine := 0;}
              end
              else
              if FDefControl <> '' then SetActive(GetControl(FDefControl))
                else SetActive(nil);
            end;
        end;
    end;
end;

procedure TGUIMemo.SetText(Text: string);
begin
  FStartLine := 0;
  FLines := GetLines(Text, FBigFont, FWidth * 16);
end;

{ TGUIimage }

procedure TGUIimage.ClearImage();
begin
  FImageRes := '';
end;

constructor TGUIimage.Create();
begin
  inherited Create();

  FImageRes := '';
end;

destructor TGUIimage.Destroy();
begin
  inherited;
end;

procedure TGUIimage.OnMessage(var Msg: TMessage);
begin
  inherited;
end;

procedure TGUIimage.SetImage(Res: string);
begin
  FImageRes := Res;
end;

procedure TGUIimage.Update();
begin
  inherited;
end;

end.
