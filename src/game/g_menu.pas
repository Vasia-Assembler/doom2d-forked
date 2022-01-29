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
unit g_menu;

interface

procedure g_Menu_Init();
procedure g_Menu_Free();
procedure g_Menu_Reset();
procedure g_Menu_AskLanguage();

procedure g_Menu_Show_SaveMenu();
procedure g_Menu_Show_LoadMenu(standalone: Boolean=false);
procedure g_Menu_Show_GameSetGame();
procedure g_Menu_Show_OptionsVideo();
procedure g_Menu_Show_OptionsSound();
procedure g_Menu_Show_EndGameMenu();
procedure g_Menu_Show_QuitGameMenu();

var
  PromptIP: string;
  PromptPort: Word;
  TempScale: Integer = -1;
  TempResScale: Integer = -1;

implementation

uses
  {$IFDEF ENABLE_GFX}
    g_gfx,
  {$ENDIF}
  {$IFDEF ENABLE_GIBS}
    g_gibs,
  {$ENDIF}
  {$IFDEF ENABLE_SHELLS}
    g_shells,
  {$ENDIF}
  {$IFDEF ENABLE_CORPSES}
    g_corpses,
  {$ENDIF}
  g_gui, r_textures, r_graphics, g_game, g_map,
  g_base, g_basic, g_console, g_sound, g_player, g_options, g_weapons,
  e_log, SysUtils, CONFIG, g_playermodel, DateUtils,
  MAPDEF, Math, g_saveload,
  g_language, e_res,
  g_net, g_netmsg, g_netmaster, g_items, e_input,
  utils, wadreader, g_system, r_render, r_game;


type TYNCallback = procedure (yes:Boolean);

procedure YNKeyDownProc (win: TGUIWindow; Key: Byte);
begin
  if win.UserData = nil then exit;
  case Key of
    IK_Y, IK_SPACE: TYNCallback(win.UserData)(true);
    IK_N: TYNCallback(win.UserData)(false);
  end;
end;

procedure YesButtonCB (ctl: TGUITextButton);
begin
  if ctl.UserData = nil then exit;
  TYNCallback(ctl.UserData)(true);
end;

procedure NoButtonCB (ctl: TGUITextButton);
begin
  if ctl.UserData = nil then exit;
  TYNCallback(ctl.UserData)(false);
end;

function CreateYNMenu (WinName, Text: String; MaxLen: Word; FontID: DWORD; ActionProc: TYNCallback): TGUIWindow;
var
  menu: TGUIMenu;
begin
  //if length(Text) = 0 then exit;
  Result := TGUIWindow.Create(WinName);
  with Result do
  begin
    //OnKeyDownEx := @YNKeyDownProc;
    //UserData := @ActionProc;
    menu := TGUIMenu(Result.AddChild(TGUIMenu.Create(gMenuSmallFont, gMenuSmallFont, '')));
    with menu do
    begin
      Name := '__temp_yes_no_menu:'+WinName;
      YesNo := true;
      AddText(Text, MaxLen);
      with AddButton(nil, _lc[I_MENU_YES]) do begin ProcEx := @YesButtonCB; UserData := @ActionProc; end;
      with AddButton(nil, _lc[I_MENU_NO]) do begin ProcEx := @NoButtonCB; UserData := @ActionProc; end;
    end;
    DefControl := '__temp_yes_no_menu:'+WinName;
    SetActive(nil);
  end;
end;


procedure ProcChangeColor(Sender: TGUIControl); forward;
procedure ProcSelectModel(Sender: TGUIControl); forward;

procedure ProcApplyOptions();
var
  menu: TGUIMenu;
  i: Integer;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsVideoMenu').GetControl('mOptionsVideoMenu'));

  if TGUISwitch(menu.GetControl('swBPP')).ItemIndex = 0 then
    gBPP := 16
  else
    gBPP := 32;

  gVSync := TGUISwitch(menu.GetControl('swVSync')).ItemIndex = 0;

  gTextureFilter := TGUISwitch(menu.GetControl('swTextureFilter')).ItemIndex = 0;
  glNPOTOverride := not (TGUISwitch(menu.GetControl('swLegacyNPOT')).ItemIndex = 0);
  gLerpActors := TGUISwitch(menu.GetControl('swInterp')).ItemIndex = 0;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsSoundMenu').GetControl('mOptionsSoundMenu'));

  g_Sound_SetupAllVolumes(
    Min(TGUIScroll(menu.GetControl('scSoundLevel')).Value*16, 255),
    Min(TGUIScroll(menu.GetControl('scMusicLevel')).Value*16, 255)
  );

  gMaxSimSounds := Max(Min(TGUIScroll(menu.GetControl('scMaxSimSounds')).Value*4+2, 66), 2);
  gMuteWhenInactive := TGUISwitch(menu.GetControl('swInactiveSounds')).ItemIndex = 1;
  gAnnouncer := TGUISwitch(menu.GetControl('swAnnouncer')).ItemIndex;
  gSoundEffectsDF := TGUISwitch(menu.GetControl('swSoundEffects')).ItemIndex = 1;
  gUseChatSounds := TGUISwitch(menu.GetControl('swChatSpeech')).ItemIndex = 0;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsGameMenu').GetControl('mOptionsGameMenu'));

  {$IFDEF ENABLE_GFX}
    g_GFX_SetMax(TGUIScroll(menu.GetControl('scParticlesCount')).Value*1000);
  {$ENDIF}
  {$IFDEF ENABLE_SHELLS}
    g_Shells_SetMax(TGUIScroll(menu.GetControl('scShellsMax')).Value*30);
  {$ENDIF}
  {$IFDEF ENABLE_GIBS}
    g_Gibs_SetMax(TGUIScroll(menu.GetControl('scGibsMax')).Value*25);
  {$ENDIF}
  {$IFDEF ENABLE_CORPSES}
    g_Corpses_SetMax(TGUIScroll(menu.GetControl('scCorpsesMax')).Value*5);
  {$ENDIF}

  {$IFDEF ENABLE_GIBS}
    case TGUISwitch(menu.GetControl('swGibsCount')).ItemIndex of
      0: gGibsCount := 0;
      1: gGibsCount := 8;
      2: gGibsCount := 16;
      3: gGibsCount := 32;
      else gGibsCount := 48;
    end;
  {$ENDIF}

  gBloodCount := TGUISwitch(menu.GetControl('swBloodCount')).ItemIndex;
  gFlash := TGUISwitch(menu.GetControl('swScreenFlash')).ItemIndex;
  gAdvBlood := TGUISwitch(menu.GetControl('swBloodType')).ItemIndex = 1;
  gAdvCorpses := TGUISwitch(menu.GetControl('swCorpseType')).ItemIndex = 1;
  gAdvGibs := TGUISwitch(menu.GetControl('swGibsType')).ItemIndex = 1;
  gDrawBackGround := TGUISwitch(menu.GetControl('swBackGround')).ItemIndex = 0;
  gShowMessages := TGUISwitch(menu.GetControl('swMessages')).ItemIndex = 0;
  gRevertPlayers := TGUISwitch(menu.GetControl('swRevertPlayers')).ItemIndex = 0;
  gChatBubble := TGUISwitch(menu.GetControl('swChatBubble')).ItemIndex;
  gPlayerIndicator := TGUISwitch(menu.GetControl('swPlayerIndicator')).ItemIndex;
  gPlayerIndicatorStyle := TGUISwitch(menu.GetControl('swPlayerIndicatorStyle')).ItemIndex;
  if TGUIScroll(menu.GetControl('scScaleFactor')).Value <> TempScale then
  begin
    TempScale := TGUIScroll(menu.GetControl('scScaleFactor')).Value;
    g_dbg_scale := TempScale + 1;
  end;


  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsMenu').GetControl('mOptionsControlsMenu'));

  with menu do
  begin
    g_Console_BindKey(g_Console_FindBind(1, 'screenshot'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_scores', '-p1_scores'), '');
    g_Console_BindKey(g_Console_FindBind(1, 'togglechat'), '');
    g_Console_BindKey(g_Console_FindBind(1, 'toggleteamchat'), '');
    g_Console_BindKey(TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_SCREENSHOT])).Key, 'screenshot');
    g_Console_BindKey(TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_STAT])).Key, '+p1_scores', '-p1_scores');
    g_Console_BindKey(TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_CHAT])).Key, 'togglechat');
    g_Console_BindKey(TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_TEAMCHAT])).Key, 'toggleteamchat');
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP1Menu').GetControl('mOptionsControlsP1Menu'));
  with menu do
  begin
    g_Console_BindKey(g_Console_FindBind(1, '+p1_moveright', '-p1_moveright'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_moveleft', '-p1_moveleft'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_lookup', '-p1_lookup'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_lookdown', '-p1_lookdown'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_attack', '-p1_attack'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_jump', '-p1_jump'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_activate', '-p1_activate'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p1_strafe', '-p1_strafe'), '');
    g_Console_BindKey(g_Console_FindBind(1, 'p1_dropflag', ''), '');
    g_Console_BindKey(g_Console_FindBind(1, 'p1_weapnext', ''), '');
    g_Console_BindKey(g_Console_FindBind(1, 'p1_weapprev', ''), '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key0, '+p1_moveright', '-p1_moveright');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key0, '+p1_moveleft', '-p1_moveleft');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key0, '+p1_lookup', '-p1_lookup');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key0, '+p1_lookdown', '-p1_lookdown');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key0, '+p1_attack', '-p1_attack');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key0, '+p1_jump', '-p1_jump');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key0, '+p1_activate', '-p1_activate');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key0, '+p1_strafe', '-p1_strafe');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key0, 'p1_dropflag', '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key0, 'p1_weapnext', '', True);
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key0, 'p1_weapprev', '', True);
    // second set
    g_Console_BindKey(g_Console_FindBind(2, '+p1_moveright', '-p1_moveright'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_moveleft', '-p1_moveleft'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_lookup', '-p1_lookup'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_lookdown', '-p1_lookdown'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_attack', '-p1_attack'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_jump', '-p1_jump'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_activate', '-p1_activate'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p1_strafe', '-p1_strafe'), '');
    g_Console_BindKey(g_Console_FindBind(2, 'p1_dropflag', ''), '');
    g_Console_BindKey(g_Console_FindBind(2, 'p1_weapnext', ''), '');
    g_Console_BindKey(g_Console_FindBind(2, 'p1_weapprev', ''), '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key1, '+p1_moveright', '-p1_moveright');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key1, '+p1_moveleft', '-p1_moveleft');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key1, '+p1_lookup', '-p1_lookup');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key1, '+p1_lookdown', '-p1_lookdown');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key1, '+p1_attack', '-p1_attack');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key1, '+p1_jump', '-p1_jump');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key1, '+p1_activate', '-p1_activate');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key1, '+p1_strafe', '-p1_strafe');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key1, 'p1_dropflag', '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key1, 'p1_weapnext', '', True);
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key1, 'p1_weapprev', '', True);
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP1MenuWeapons').GetControl('mOptionsControlsP1MenuWeapons'));
  with menu do
  begin
    for i := WP_FIRST to WP_LAST do
    begin
      g_Console_BindKey(g_Console_FindBind(1, 'p1_weapon ' + IntToStr(i + 1)), '');
      g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key0, 'p1_weapon ' + IntToStr(i + 1));
      g_Console_BindKey(g_Console_FindBind(2, 'p1_weapon ' + IntToStr(i + 1)), '');
      g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key1, 'p1_weapon ' + IntToStr(i + 1));
    end;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP2Menu').GetControl('mOptionsControlsP2Menu'));
  with menu do
  begin
    g_Console_BindKey(g_Console_FindBind(1, '+p2_moveright', '-p2_moveright'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_moveleft', '-p2_moveleft'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_lookup', '-p2_lookup'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_lookdown', '-p2_lookdown'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_attack', '-p2_attack'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_jump', '-p2_jump'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_activate', '-p2_activate'), '');
    g_Console_BindKey(g_Console_FindBind(1, '+p2_strafe', '-p2_strafe'), '');
    g_Console_BindKey(g_Console_FindBind(1, 'p2_dropflag', ''), '');
    g_Console_BindKey(g_Console_FindBind(1, 'p2_weapnext', ''), '');
    g_Console_BindKey(g_Console_FindBind(1, 'p2_weapprev', ''), '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key0, '+p2_moveright', '-p2_moveright');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key0, '+p2_moveleft', '-p2_moveleft');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key0, '+p2_lookup', '-p2_lookup');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key0, '+p2_lookdown', '-p2_lookdown');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key0, '+p2_attack', '-p2_attack');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key0, '+p2_jump', '-p2_jump');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key0, '+p2_activate', '-p2_activate');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key0, '+p2_strafe', '-p2_strafe');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key0, 'p2_dropflag', '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key0, 'p2_weapnext', '', True);
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key0, 'p2_weapprev', '', True);
    // second set
    g_Console_BindKey(g_Console_FindBind(2, '+p2_moveright', '-p2_moveright'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_moveleft', '-p2_moveleft'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_lookup', '-p2_lookup'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_lookdown', '-p2_lookdown'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_attack', '-p2_attack'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_jump', '-p2_jump'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_activate', '-p2_activate'), '');
    g_Console_BindKey(g_Console_FindBind(2, '+p2_strafe', '-p2_strafe'), '');
    g_Console_BindKey(g_Console_FindBind(2, 'p2_dropflag', ''), '');
    g_Console_BindKey(g_Console_FindBind(2, 'p2_weapnext', ''), '');
    g_Console_BindKey(g_Console_FindBind(2, 'p2_weapprev', ''), '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key1, '+p2_moveright', '-p2_moveright');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key1, '+p2_moveleft', '-p2_moveleft');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key1, '+p2_lookup', '-p2_lookup');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key1, '+p2_lookdown', '-p2_lookdown');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key1, '+p2_attack', '-p2_attack');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key1, '+p2_jump', '-p2_jump');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key1, '+p2_activate', '-p2_activate');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key1, '+p2_strafe', '-p2_strafe');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key1, 'p2_dropflag', '');
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key1, 'p2_weapnext', '', True);
    g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key1, 'p2_weapprev', '', True);
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP2MenuWeapons').GetControl('mOptionsControlsP2MenuWeapons'));
  with menu do
  begin
    for i := WP_FIRST to WP_LAST do
    begin
      g_Console_BindKey(g_Console_FindBind(1, 'p2_weapon ' + IntToStr(i + 1)), '');
      g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key0, 'p2_weapon ' + IntToStr(i + 1));
      g_Console_BindKey(g_Console_FindBind(2, 'p2_weapon ' + IntToStr(i + 1)), '');
      g_Console_BindKey(TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key1, 'p2_weapon ' + IntToStr(i + 1));
    end;
  end;

  if e_HasJoysticks then
  begin
    menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsJoystickMenu').GetControl('mOptionsControlsJoystickMenu'));
    with menu do
    begin
      for i := 0 to e_MaxJoys - 1 do
        if e_JoystickAvailable[i] then
          e_JoystickDeadzones[i] := TGUIScroll(menu.GetControl('scDeadzone' + IntToStr(i))).Value*(32767 div 20)
    end
  end;

  if g_touch_enabled then
  begin
    menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsTouchMenu').GetControl('mOptionsControlsTouchMenu'));
    g_touch_alt := TGUISwitch(menu.GetControl('swTouchAlt')).ItemIndex = 1;
    g_touch_size := TGUIScroll(menu.GetControl('scTouchSize')).Value / 10 + 0.5;
    g_touch_fire := TGUISwitch(menu.GetControl('swTouchFire')).ItemIndex = 1;
    g_touch_offset := TGUIScroll(menu.GetControl('scTouchOffset')).Value * 5;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP1Menu').GetControl('mOptionsPlayersP1Menu'));

  gPlayer1Settings.Name := b_Text_Unformat(TGUIEdit(menu.GetControl('edP1Name')).Text);
  gPlayer1Settings.Team := IfThen(TGUISwitch(menu.GetControl('swP1Team')).ItemIndex = 0,
                                  TEAM_RED, TEAM_BLUE);

  with TGUIModelView(g_GUI_GetWindow('OptionsPlayersP1Menu').GetControl('mvP1Model')) do
  begin
    gPlayer1Settings.Model := Model.GetName();
    gPlayer1Settings.Color := Model.Color;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP1Menu').GetControl('mOptionsPlayersP1Menu'));

  gPlayer1Settings.Name := b_Text_Unformat(TGUIEdit(menu.GetControl('edP1Name')).Text);
  gPlayer1Settings.Team := IfThen(TGUISwitch(menu.GetControl('swP1Team')).ItemIndex = 0,
                                  TEAM_RED, TEAM_BLUE);

  with TGUIModelView(g_GUI_GetWindow('OptionsPlayersP1Menu').GetControl('mvP1Model')) do
  begin
    gPlayer1Settings.Model := Model.GetName();
    gPlayer1Settings.Color := Model.Color;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP1WeaponMenu').GetControl('mOptionsPlayersP1WeaponMenu'));
  gPlayer1Settings.WeaponSwitch := TGUISwitch(menu.GetControl('swWeaponAutoswitch')).ItemIndex;
  gPlayer1Settings.SwitchToEmpty := TGUISwitch(menu.GetControl('swWeaponAllowEmpty')).ItemIndex;
  gPlayer1Settings.SkipFist := TGUISwitch(menu.GetControl('swWeaponAllowFist')).ItemIndex;
  
  menu := TGUIMenu(g_GUI_GetWindow('OptionsPreferencesP1WeaponMenu').GetControl('mOptionsPreferencesP1WeaponMenu'));
  with menu do
  begin
    for i := WP_FIRST to WP_LAST+1 do
    begin
      gPlayer1Settings.WeaponPreferences[i] := TGUISwitch(menu.GetControl(IntToStr(i))).ItemIndex;
    end;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP2WeaponMenu').GetControl('mOptionsPlayersP2WeaponMenu'));
  gPlayer2Settings.WeaponSwitch := TGUISwitch(menu.GetControl('swWeaponAutoswitch')).ItemIndex;
  gPlayer2Settings.SwitchToEmpty := TGUISwitch(menu.GetControl('swWeaponAllowEmpty')).ItemIndex;
  gPlayer2Settings.SkipFist := TGUISwitch(menu.GetControl('swWeaponAllowFist')).ItemIndex;
  menu := TGUIMenu(g_GUI_GetWindow('OptionsPreferencesP2WeaponMenu').GetControl('mOptionsPreferencesP2WeaponMenu'));
  with menu do
  begin
    for i := WP_FIRST to WP_LAST+1 do
    begin
      gPlayer2Settings.WeaponPreferences[i] := TGUISwitch(menu.GetControl(IntToStr(i))).ItemIndex;
    end;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP2Menu').GetControl('mOptionsPlayersP2Menu'));

  gPlayer2Settings.Name := b_Text_Unformat(TGUIEdit(menu.GetControl('edP2Name')).Text);
  gPlayer2Settings.Team := IfThen(TGUISwitch(menu.GetControl('swP2Team')).ItemIndex = 0,
                                  TEAM_RED, TEAM_BLUE);
  with TGUIModelView(g_GUI_GetWindow('OptionsPlayersP2Menu').GetControl('mvP2Model')) do
  begin
    gPlayer2Settings.Model := Model.GetName();
    gPlayer2Settings.Color := Model.Color;
  end;

  if gPlayer1Settings.Name = '' then gPlayer1Settings.Name := GenPlayerName(1);
  if gPlayer2Settings.Name = '' then gPlayer2Settings.Name := GenPlayerName(2);

  if g_Game_IsServer then
  begin
    if gPlayer1 <> nil then
    begin
      gPlayer1.SetModel(gPlayer1Settings.Model);
      gPlayer1.Name := gPlayer1Settings.Name;
      if not (gGameSettings.GameMode in [GM_TDM, GM_CTF]) then
        gPlayer1.SetColor(gPlayer1Settings.Color)
      else
        if gPlayer1.Team <> gPlayer1Settings.Team then
          gPlayer1.SwitchTeam;
      gPlayer1.WeapSwitchMode := gPlayer1Settings.WeaponSwitch;
      gPlayer1.setWeaponPrefs(gPlayer1Settings.WeaponPreferences);
      gPlayer1.SwitchToEmpty := gPlayer1Settings.SwitchToEmpty;
      gPlayer1.SkipFist := gPlayer1Settings.SkipFist;
      if g_Game_IsNet then MH_SEND_PlayerSettings(gPlayer1.UID);
    end;

    if gPlayer2 <> nil then
    begin
      gPlayer2.SetModel(gPlayer2Settings.Model);
      gPlayer2.Name := gPlayer2Settings.Name;
      if (gGameSettings.GameMode <> GM_TDM) and (gGameSettings.GameMode <> GM_CTF) then
        gPlayer2.SetColor(gPlayer2Settings.Color)
      else
        if gPlayer2.Team <> gPlayer2Settings.Team then
          gPlayer2.SwitchTeam;
      gPlayer2.WeapSwitchMode := gPlayer2Settings.WeaponSwitch;
      gPlayer2.setWeaponPrefs(gPlayer2Settings.WeaponPreferences);
      gPlayer2.SwitchToEmpty := gPlayer2Settings.SwitchToEmpty;
      gPlayer2.SkipFist := gPlayer2Settings.SkipFist;
    end;
  end;

  if g_Game_IsClient then
  begin
    MC_SEND_PlayerSettings;
    gPlayer1.setWeaponPrefs(gPlayer1Settings.WeaponPreferences);
  end;

  g_Console_WriteGameConfig;
end;

procedure ReadOptions();
var
  menu: TGUIMenu;
  i: Integer;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsVideoMenu').GetControl('mOptionsVideoMenu'));

  with TGUISwitch(menu.GetControl('swBPP')) do
    if gBPP = 16 then
      ItemIndex := 0
    else
      ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swTextureFilter')) do
    if gTextureFilter then ItemIndex := 0 else ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swVSync')) do
    if gVSync then ItemIndex := 0 else ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swLegacyNPOT')) do
    if not glNPOTOverride then ItemIndex := 0 else ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swInterp')) do
    if gLerpActors then ItemIndex := 0 else ItemIndex := 1;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsSoundMenu').GetControl('mOptionsSoundMenu'));

  TGUIScroll(menu.GetControl('scSoundLevel')).Value := Round(gSoundLevel/16);
  TGUIScroll(menu.GetControl('scMusicLevel')).Value := Round(gMusicLevel/16);
  TGUIScroll(menu.GetControl('scMaxSimSounds')).Value := Round((gMaxSimSounds-2)/4);

  with TGUISwitch(menu.GetControl('swInactiveSounds')) do
    if gMuteWhenInactive then
      ItemIndex := 1
    else
      ItemIndex := 0;

  TGUISwitch(menu.GetControl('swAnnouncer')).ItemIndex := gAnnouncer;

  with TGUISwitch(menu.GetControl('swSoundEffects')) do
    if gSoundEffectsDF then
      ItemIndex := 1
    else
      ItemIndex := 0;

  with TGUISwitch(menu.GetControl('swChatSpeech')) do
    if gUseChatSounds then
      ItemIndex := 0
    else
      ItemIndex := 1;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP1Menu').GetControl('mOptionsControlsP1Menu'));
  with menu do
  begin
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key0 := g_Console_FindBind(1, '+p1_moveright', '-p1_moveright');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key0 := g_Console_FindBind(1, '+p1_moveleft', '-p1_moveleft');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key0 := g_Console_FindBind(1, '+p1_lookup', '-p1_lookup');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key0 := g_Console_FindBind(1, '+p1_lookdown', '-p1_lookdown');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key0 := g_Console_FindBind(1, '+p1_attack', '-p1_attack');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key0 := g_Console_FindBind(1, '+p1_jump', '-p1_jump');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key0 := g_Console_FindBind(1, '+p1_activate', '-p1_activate');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key0 := g_Console_FindBind(1, '+p1_strafe', '-p1_strafe');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key0 := g_Console_FindBind(1, 'p1_dropflag', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key0 := g_Console_FindBind(1, 'p1_weapnext', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key0 := g_Console_FindBind(1, 'p1_weapprev', '');
    // second set
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key1 := g_Console_FindBind(2, '+p1_moveright', '-p1_moveright');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key1 := g_Console_FindBind(2, '+p1_moveleft', '-p1_moveleft');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key1 := g_Console_FindBind(2, '+p1_lookup', '-p1_lookup');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key1 := g_Console_FindBind(2, '+p1_lookdown', '-p1_lookdown');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key1 := g_Console_FindBind(2, '+p1_attack', '-p1_attack');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key1 := g_Console_FindBind(2, '+p1_jump', '-p1_jump');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key1 := g_Console_FindBind(2, '+p1_activate', '-p1_activate');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key1 := g_Console_FindBind(2, '+p1_strafe', '-p1_strafe');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key1 := g_Console_FindBind(2, 'p1_dropflag', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key1 := g_Console_FindBind(2, 'p1_weapnext', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key1 := g_Console_FindBind(2, 'p1_weapprev', '');
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP1MenuWeapons').GetControl('mOptionsControlsP1MenuWeapons'));
  with menu do
  begin
    for i := WP_FIRST to WP_LAST do
    begin
      TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key0 := g_Console_FindBind(1, 'p1_weapon ' + IntToStr(i + 1));
      TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key1 := g_Console_FindBind(2, 'p1_weapon ' + IntToStr(i + 1));
    end;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP2Menu').GetControl('mOptionsControlsP2Menu'));
  with menu do
  begin
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key0 := g_Console_FindBind(1, '+p2_moveright', '-p2_moveright');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key0 := g_Console_FindBind(1, '+p2_moveleft', '-p2_moveleft');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key0 := g_Console_FindBind(1, '+p2_lookup', '-p2_lookup');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key0 := g_Console_FindBind(1, '+p2_lookdown', '-p2_lookdown');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key0 := g_Console_FindBind(1, '+p2_attack', '-p2_attack');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key0 := g_Console_FindBind(1, '+p2_jump', '-p2_jump');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key0 := g_Console_FindBind(1, '+p2_activate', '-p2_activate');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key0 := g_Console_FindBind(1, '+p2_strafe', '-p2_strafe');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key0 := g_Console_FindBind(1, 'p2_dropflag', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key0 := g_Console_FindBind(1, 'p2_weapnext', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key0 := g_Console_FindBind(1, 'p2_weapprev', '');
    // second set
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_RIGHT])).Key1 := g_Console_FindBind(2, '+p2_moveright', '-p2_moveright');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_LEFT])).Key1 := g_Console_FindBind(2, '+p2_moveleft', '-p2_moveleft');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_UP])).Key1 := g_Console_FindBind(2, '+p2_lookup', '-p2_lookup');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DOWN])).Key1 := g_Console_FindBind(2, '+p2_lookdown', '-p2_lookdown');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_FIRE])).Key1 := g_Console_FindBind(2, '+p2_attack', '-p2_attack');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_JUMP])).Key1 := g_Console_FindBind(2, '+p2_jump', '-p2_jump');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_USE])).Key1 := g_Console_FindBind(2, '+p2_activate', '-p2_activate');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_STRAFE])).Key1 := g_Console_FindBind(2, '+p2_strafe', '-p2_strafe');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_DROPFLAG])).Key1 := g_Console_FindBind(2, 'p2_dropflag', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_NEXT_WEAPON])).Key1 := g_Console_FindBind(2, 'p2_weapnext', '');
    TGUIKeyRead2(GetControl(_lc[I_MENU_CONTROL_PREV_WEAPON])).Key1 := g_Console_FindBind(2, 'p2_weapprev', '');
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsP2MenuWeapons').GetControl('mOptionsControlsP2MenuWeapons'));
  with menu do
  begin
    for i := WP_FIRST to WP_LAST do
    begin
      TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key0 := g_Console_FindBind(1, 'p2_weapon ' + IntToStr(i + 1));
      TGUIKeyRead2(GetControl(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)])).Key1 := g_Console_FindBind(2, 'p2_weapon ' + IntToStr(i + 1));
    end;
  end;

  if e_HasJoysticks then
  begin
    menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsJoystickMenu').GetControl('mOptionsControlsJoystickMenu'));
    with menu do
    begin
      for i := 0 to e_MaxJoys - 1 do
        if e_JoystickAvailable[i] then
          TGUIScroll(menu.GetControl('scDeadzone' + IntToStr(i))).Value := e_JoystickDeadzones[i] div (32767 div 20)
    end
  end;

  if g_touch_enabled then
  begin
    menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsTouchMenu').GetControl('mOptionsControlsTouchMenu'));
    with TGUISwitch(menu.GetControl('swTouchAlt')) do
      if g_touch_alt then ItemIndex := 1 else ItemIndex := 0;
    TGUIScroll(menu.GetControl('scTouchSize')).Value := Round((g_touch_size - 0.5) * 10);
    with TGUISwitch(menu.GetControl('swTouchFire')) do
      if g_touch_fire then ItemIndex := 1 else ItemIndex := 0;
    TGUIScroll(menu.GetControl('scTouchOffset')).Value := Round(g_touch_offset / 5);
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsMenu').GetControl('mOptionsControlsMenu'));
  with menu do
  begin
    TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_SCREENSHOT])).Key := g_Console_FindBind(1, 'screenshot');
    TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_STAT])).Key := g_Console_FindBind(1, '+p1_scores', '-p1_scores');
    TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_CHAT])).Key := g_Console_FindBind(1, 'togglechat');
    TGUIKeyRead(GetControl(_lc[I_MENU_CONTROL_TEAMCHAT])).Key := g_Console_FindBind(1, 'toggleteamchat');
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsGameMenu').GetControl('mOptionsGameMenu'));

  {$IFDEF ENABLE_GFX}
    TGUIScroll(menu.GetControl('scParticlesCount')).Value := g_GFX_GetMax() div 1000;
  {$ENDIF}
  {$IFDEF ENABLE_SHELLS}
    TGUIScroll(menu.GetControl('scShellsMax')).Value := g_Shells_GetMax() div 30;
  {$ENDIF}
  {$IFDEF ENABLE_GIBS}
    TGUIScroll(menu.GetControl('scGibsMax')).Value := g_Gibs_GetMax() div 25;
  {$ENDIF}
  {$IFDEF ENABLE_CORPSES}
    TGUIScroll(menu.GetControl('scCorpsesMax')).Value := g_Corpses_GetMax() div 5;
  {$ENDIF}
  TGUISwitch(menu.GetControl('swBloodCount')).ItemIndex := gBloodCount;

  with TGUISwitch(menu.GetControl('swScreenFlash')) do
    ItemIndex := gFlash;

  with TGUISwitch(menu.GetControl('swBloodType')) do
    if gAdvBlood then ItemIndex := 1 else ItemIndex := 0;

  with TGUISwitch(menu.GetControl('swCorpseType')) do
    if gAdvCorpses then ItemIndex := 1 else ItemIndex := 0;

  with TGUISwitch(menu.GetControl('swGibsType')) do
    if gAdvGibs then ItemIndex := 1 else ItemIndex := 0;

  {$IFDEF ENABLE_GIBS}
    with TGUISwitch(menu.GetControl('swGibsCount')) do
    begin
      case gGibsCount of
        0: ItemIndex := 0;
        8: ItemIndex := 1;
        16: ItemIndex := 2;
        32: ItemIndex := 3;
        else ItemIndex := 4;
      end;
    end;
  {$ENDIF}

  with TGUISwitch(menu.GetControl('swBackGround')) do
    if gDrawBackGround then ItemIndex := 0 else ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swMessages')) do
    if gShowMessages then ItemIndex := 0 else ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swRevertPlayers')) do
    if gRevertPlayers then ItemIndex := 0 else ItemIndex := 1;

  with TGUISwitch(menu.GetControl('swChatBubble')) do
    ItemIndex := gChatBubble;

  with TGUISwitch(menu.GetControl('swPlayerIndicator')) do
    ItemIndex := gPlayerIndicator;

  with TGUISwitch(menu.GetControl('swPlayerIndicatorStyle')) do
    ItemIndex := gPlayerIndicatorStyle;

  TempScale := Round(g_dbg_scale - 1);
  TGUIScroll(menu.GetControl('scScaleFactor')).Value := TempScale;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP1Menu').GetControl('mOptionsPlayersP1Menu'));

  TGUIListBox(menu.GetControl('lsP1Model')).SelectItem(gPlayer1Settings.Model);
  TGUIEdit(menu.GetControl('edP1Name')).Text := gPlayer1Settings.Name;

  TGUISwitch(menu.GetControl('swP1Team')).ItemIndex :=
    IfThen(gPlayer1Settings.Team = TEAM_BLUE, 1, 0);

  TGUIScroll(menu.GetControl('scP1Red')).Value := Round(gPlayer1Settings.Color.R/16);
  TGUIScroll(menu.GetControl('scP1Green')).Value := Round(gPlayer1Settings.Color.G/16);
  TGUIScroll(menu.GetControl('scP1Blue')).Value := Round(gPlayer1Settings.Color.B/16);

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP1WeaponMenu').GetControl('mOptionsPlayersP1WeaponMenu'));
  TGUISwitch(menu.GetControl('swWeaponAutoswitch')).ItemIndex := gPlayer1Settings.WeaponSwitch;
  TGUISwitch(menu.GetControl('swWeaponAllowEmpty')).ItemIndex := gPlayer1Settings.SwitchToEmpty;
  TGUISwitch(menu.GetControl('swWeaponAllowFist')).ItemIndex := gPlayer1Settings.SkipFist;
  menu := TGUIMenu(g_GUI_GetWindow('OptionsPreferencesP1WeaponMenu').GetControl('mOptionsPreferencesP1WeaponMenu'));
  for i := WP_FIRST to WP_LAST+1 do
  begin
        if (gPlayer1Settings.WeaponPreferences[i] > 0) and (gPlayer1Settings.WeaponPreferences[i] <= WP_LAST+1) then TGUISwitch(menu.GetControl(IntToStr(i))).ItemIndex := gPlayer1Settings.WeaponPreferences[i]
        else TGUISwitch(menu.GetControl(IntToStr(i))).ItemIndex := 0;
  end;

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP2WeaponMenu').GetControl('mOptionsPlayersP2WeaponMenu'));
  TGUISwitch(menu.GetControl('swWeaponAutoswitch')).ItemIndex := gPlayer2Settings.WeaponSwitch;
  TGUISwitch(menu.GetControl('swWeaponAllowEmpty')).ItemIndex := gPlayer2Settings.SwitchToEmpty;
  TGUISwitch(menu.GetControl('swWeaponAllowFist')).ItemIndex := gPlayer2Settings.SkipFist;
  menu := TGUIMenu(g_GUI_GetWindow('OptionsPreferencesP2WeaponMenu').GetControl('mOptionsPreferencesP2WeaponMenu'));
  for i := WP_FIRST to WP_LAST+1 do
  begin
        if (gPlayer2Settings.WeaponPreferences[i] > 0) and (gPlayer2Settings.WeaponPreferences[i] <= WP_LAST+1) then TGUISwitch(menu.GetControl(IntToStr(i))).ItemIndex := gPlayer2Settings.WeaponPreferences[i]
        else TGUISwitch(menu.GetControl(IntToStr(i))).ItemIndex := 0;
  end;  

  menu := TGUIMenu(g_GUI_GetWindow('OptionsPlayersP2Menu').GetControl('mOptionsPlayersP2Menu'));

  TGUIListBox(menu.GetControl('lsP2Model')).SelectItem(gPlayer2Settings.Model);
  TGUIEdit(menu.GetControl('edP2Name')).Text := gPlayer2Settings.Name;

  TGUISwitch(menu.GetControl('swP2Team')).ItemIndex :=
    IfThen(gPlayer2Settings.Team = TEAM_BLUE, 1, 0);

  TGUIScroll(menu.GetControl('scP2Red')).Value := Round(gPlayer2Settings.Color.R/16);
  TGUIScroll(menu.GetControl('scP2Green')).Value := Round(gPlayer2Settings.Color.G/16);
  TGUIScroll(menu.GetControl('scP2Blue')).Value := Round(gPlayer2Settings.Color.B/16);

  ProcSelectModel(nil);
end;

procedure ProcSwitchMonstersCustom(Sender: TGUIControl);
begin
  // don't turn off monsters in DM
  {
  with TGUIMenu(g_ActiveWindow.GetControl('mCustomGameMenu')) do
    if TGUISwitch(GetControl('swGameMode')).GetText <> _lc[I_MENU_GAME_TYPE_CTF] then
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 0
    else
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 1;
  }
  {
    if TGUISwitch(GetControl('swGameMode')).GetText = _lc[I_MENU_GAME_TYPE_COOP] then
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 0
    else if TGUISwitch(GetControl('swGameMode')).GetText = _lc[I_MENU_GAME_TYPE_CTF] then
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 1;
  }
end;

procedure ProcSwitchMonstersNet(Sender: TGUIControl);
begin
  // don't turn off monsters in DM
  {
  with TGUIMenu(g_ActiveWindow.GetControl('mNetServerMenu')) do
    if TGUISwitch(GetControl('swGameMode')).GetText <> _lc[I_MENU_GAME_TYPE_CTF] then
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 0
    else
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 1;
  }
    {
    if TGUISwitch(GetControl('swGameMode')).GetText = _lc[I_MENU_GAME_TYPE_COOP] then
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 0
    else if TGUISwitch(GetControl('swGameMode')).GetText = _lc[I_MENU_GAME_TYPE_CTF] then
      TGUISwitch(GetControl('swMonsters')).ItemIndex := 1;
    }
end;

function LatchGameOptions(const MenuName: string): Byte;
var
  Map: string;
begin
  Result := GM_NONE;

  with TGUIMenu(g_ActiveWindow.GetControl(MenuName)) do
  begin
    Map := TGUILabel(GetControl('lbMap')).Text;
    if Map = '' then
      Exit;
    if not isWadPath(Map) then
      Exit;

    Result := TGUISwitch(GetControl('swGameMode')).ItemIndex+1;
    gsGameMode := TGUISwitch(GetControl('swGameMode')).GetText;
    gsTimeLimit := StrToIntDef(TGUIEdit(GetControl('edTimeLimit')).Text, 0);
    gsGoalLimit := StrToIntDef(TGUIEdit(GetControl('edGoalLimit')).Text, 0);
    gsMaxLives := StrToIntDef(TGUIEdit(GetControl('edMaxLives')).Text, 0);
    gsItemRespawnTime := StrToIntDef(TGUIEdit(GetControl('edItemRespawnTime')).Text, 0);
    gsPlayers := TGUISwitch(GetControl('swPlayers')).ItemIndex;
    gsMap := Map;

    gsGameFlags := 0;
    if TGUISwitch(GetControl('swTeamDamage')).ItemIndex = 0 then
      gsGameFlags := gsGameFlags or GAME_OPTION_TEAMDAMAGE;
    if TGUISwitch(GetControl('swDeathmatchKeys')).ItemIndex = 0 then
      gsGameFlags := gsGameFlags or GAME_OPTION_DMKEYS;
    if TGUISwitch(GetControl('swEnableExits')).ItemIndex = 0 then
      gsGameFlags := gsGameFlags or GAME_OPTION_ALLOWEXIT;
    if TGUISwitch(GetControl('swWeaponStay')).ItemIndex = 0 then
      gsGameFlags := gsGameFlags or GAME_OPTION_WEAPONSTAY;
    if TGUISwitch(GetControl('swMonsters')).ItemIndex = 0 then
      gsGameFlags := gsGameFlags or GAME_OPTION_MONSTERS;

    case TGUISwitch(GetControl('swTeamHit')).ItemIndex of
      1: gsGameFlags := gsGameFlags or GAME_OPTION_TEAMHITTRACE;
      2: gsGameFlags := gsGameFlags or GAME_OPTION_TEAMHITPROJECTILE;
      0: gsGameFlags := gsGameFlags or GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE;
    end;

    case TGUISwitch(GetControl('swBotsVS')).ItemIndex of
      1: gsGameFlags := gsGameFlags or GAME_OPTION_BOTVSMONSTER;
      2: gsGameFlags := gsGameFlags or GAME_OPTION_BOTVSPLAYER or GAME_OPTION_BOTVSMONSTER;
      else gsGameFlags := gsGameFlags or GAME_OPTION_BOTVSPLAYER;
    end;

    case TGUISwitch(GetControl('swFlagDrop')).ItemIndex of
      0: gsGameFlags := gsGameFlags or GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG;
      1: gsGameFlags := gsGameFlags or GAME_OPTION_ALLOWDROPFLAG;
      else gsGameFlags := gsGameFlags and not (GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG);
    end;

    // TODO: get this crap out of here
    gGameSettings.ItemRespawnTime := gsItemRespawnTime;
    gGameSettings.WarmupTime := gsWarmupTime;
    gGameSettings.SpawnInvul := gsSpawnInvul;
  end;
end;

procedure ProcStartCustomGame();
var
  GameMode: Byte;
begin
  GameMode := LatchGameOptions('mCustomGameMenu');
  if GameMode = GM_NONE then Exit;

  g_Console_WriteGameConfig;
  g_Game_StartCustom(gsMap, GameMode, gsTimeLimit, gsGoalLimit,
                     gsMaxLives, gsGameFlags, gsPlayers);
end;


procedure ProcStartNetGame();
var
  GameMode: Byte;
begin
  GameMode := LatchGameOptions('mNetServerMenu');
  if GameMode = GM_NONE then Exit;

  with TGUIMenu(g_ActiveWindow.GetControl('mNetServerMenu')) do
  begin
    NetPort := StrToIntDef(TGUIEdit(GetControl('edPort')).Text, 0);
    NetServerName := TGUIEdit(GetControl('edSrvName')).Text;
    NetMaxClients := Max(1, StrToIntDef(TGUIEdit(GetControl('edMaxPlayers')).Text, 1));
    NetMaxClients := Min(NET_MAXCLIENTS, NetMaxClients);
    NetPassword := TGUIEdit(GetControl('edSrvPassword')).Text;
    NetUseMaster := TGUISwitch(GetControl('swUseMaster')).ItemIndex = 0;
  end;

  g_Console_WriteGameConfig;
  g_Game_StartServer(gsMap, GameMode, gsTimeLimit, gsGoalLimit, gsMaxLives,
                     gsGameFlags, gsPlayers, 0, NetPort);
end;

procedure ProcConnectNetGame();
var
  PW: String;
begin
  with TGUIMenu(g_ActiveWindow.GetControl('mNetClientMenu')) do
  begin
    NetClientIP := TGUIEdit(GetControl('edIP')).Text;
    NetClientPort := StrToIntDef(TGUIEdit(GetControl('edPort')).Text, 0);
    PW := TGUIEdit(GetControl('edPW')).Text;
  end;

  g_Console_WriteGameConfig;
  g_Game_StartClient(NetClientIP, NetClientPort, PW);
end;

procedure ProcEnterPassword();
var
  PW: string;
begin
  with TGUIMenu(g_ActiveWindow.GetControl('mClientPasswordMenu')) do
  begin
    NetClientIP := PromptIP;
    NetClientPort := PromptPort;
    PW := TGUIEdit(GetControl('edPW')).Text;
  end;

  g_Console_WriteGameConfig;
  g_Game_StartClient(NetClientIP, NetClientPort, PW);
end;

procedure ProcServerlist();
begin
  if not NetInitDone then
  begin
    if (not g_Net_Init()) then
    begin
      g_Console_Add('NET: ERROR: Failed to init ENet!');
      Exit;
    end
    else
      NetInitDone := True;
  end;

  g_Net_Slist_Set(NetMasterList);

  gState := STATE_SLIST;
  g_ActiveWindow := nil;

  slWaitStr := _lc[I_NET_SLIST_WAIT];

  r_Render_Draw;
  sys_Repaint;

  slReturnPressed := True;
  if g_Net_Slist_Fetch(slCurrent) then
  begin
    if slCurrent = nil then
      slWaitStr := _lc[I_NET_SLIST_NOSERVERS];
  end
  else
    slWaitStr := _lc[I_NET_SLIST_ERROR];
  g_Serverlist_GenerateTable(slCurrent, slTable);
end;

procedure ProcStartCampaign();
var
  WAD: String;
  TwoPlayers: Boolean;
  n: Byte;
begin
  with TGUIMenu(g_ActiveWindow.GetControl('mCampaignMenu')) do
  begin
    WAD := TGUIFileListBox(GetControl('lsWAD')).SelectedItem();
    TwoPlayers := TGUISwitch(GetControl('swPlayers')).ItemIndex = 1;
  end;
  WAD := e_FindWadRel(MegawadDirs, WAD);

  if TwoPlayers then
    n := 2
  else
    n := 1;
  g_Game_StartSingle(WAD + ':\MAP01', TwoPlayers, n);
end;

procedure ProcSelectMap(Sender: TGUIControl);
var
  win: TGUIWindow;
  a: TMapInfo;
  wad, map, res: String;
begin
  win := g_GUI_GetWindow('SelectMapMenu');
  with TGUIMenu(win.GetControl('mSelectMapMenu')) do
  begin
    wad := TGUIFileListBox(GetControl('lsMapWAD')).SelectedItem();
    map := TGUIListBox(GetControl('lsMapRes')).SelectedItem();

    if (wad = '') or (map = '') then
      begin // ��� �� �����
        TGUILabel(GetControl('lbMapName')).Text := '';
        TGUILabel(GetControl('lbMapAuthor')).Text := '';
        TGUILabel(GetControl('lbMapSize')).Text := '';
        TGUIMemo(GetControl('meMapDescription')).SetText('');
        TGUIMapPreview(win.GetControl('mpMapPreview')).ClearMap();
        TGUILabel(win.GetControl('lbMapScale')).Text := '';
      end
    else // ��� �����
      begin
        res := wad+':\'+map;

        a := g_Map_GetMapInfo(res);

        TGUILabel(GetControl('lbMapName')).Text := a.Name;
        TGUILabel(GetControl('lbMapAuthor')).Text := a.Author;
        TGUILabel(GetControl('lbMapSize')).Text := Format('%dx%d', [a.Width, a.Height]);
        TGUIMemo(GetControl('meMapDescription')).SetText(a.Description);
        TGUIMapPreview(win.GetControl('mpMapPreview')).SetMap(res);
        TGUILabel(win.GetControl('lbMapScale')).Text :=
          TGUIMapPreview(win.GetControl('mpMapPreview')).GetScaleStr;
      end;
  end;
end;

procedure ProcSelectWAD(Sender: TGUIControl);
var
  wad: String;
  list: SSArray;
begin
  with TGUIMenu(g_GUI_GetWindow('SelectMapMenu').GetControl('mSelectMapMenu')) do
  begin
    wad := TGUIFileListBox(GetControl('lsMapWAD')).SelectedItem();

    with TGUIListBox(GetControl('lsMapRes')) do
    begin
      Clear();

      if wad <> '' then
      begin
        list := g_Map_GetMapsList(wad);

        if list <> nil then
        begin
          Items := list;
          ItemIndex := 0;
        end
      end;
    end;
 end;

 ProcSelectMap(nil);
end;

procedure ProcSelectCampaignWAD(Sender: TGUIControl);
var
  win: TGUIWindow;
  a: TMegaWADInfo;
  wad, fn: String;
begin
  win := g_GUI_GetWindow('CampaignMenu');
  with TGUIMenu(win.GetControl('mCampaignMenu')) do
  begin
    wad := TGUIFileListBox(GetControl('lsWAD')).SelectedItem();

    if wad = '' then
    begin
      TGUILabel(GetControl('lbWADName')).Text := '';
      TGUILabel(GetControl('lbWADAuthor')).Text := '';
      TGUIMemo(GetControl('meWADDescription')).SetText('');
    end;

    a := g_Game_GetMegaWADInfo(wad);

    TGUILabel(GetControl('lbWADName')).Text := a.Name;
    TGUILabel(GetControl('lbWADAuthor')).Text := a.Author;
    TGUIMemo(GetControl('meWADDescription')).SetText(a.Description);

    TGUIImage(win.GetControl('mpWADImage')).ClearImage();

    if a.pic <> '' then
    begin
      fn := g_ExtractWadName(a.pic);
      if fn = '' then
        TGUIImage(win.GetControl('mpWADImage')).SetImage(wad+a.pic)
      else
        TGUIImage(win.GetControl('mpWADImage')).SetImage(a.pic);
    end;
  end;
end;

procedure ProcChangeColor(Sender: TGUIControl);
var
  window: TGUIWindow;
begin
  window := g_GUI_GetWindow('OptionsPlayersP1Menu');
  with TGUIMenu(window.GetControl('mOptionsPlayersP1Menu')) do
    TGUIModelView(window.GetControl('mvP1Model')).SetColor(
                  Min(TGUIScroll(GetControl('scP1Red')).Value*16, 255),
                  Min(TGUIScroll(GetControl('scP1Green')).Value*16, 255),
                  Min(TGUIScroll(GetControl('scP1Blue')).Value*16, 255));

  window := g_GUI_GetWindow('OptionsPlayersP2Menu');
  with TGUIMenu(window.GetControl('mOptionsPlayersP2Menu')) do
    TGUIModelView(window.GetControl('mvP2Model')).SetColor(
                  Min(TGUIScroll(GetControl('scP2Red')).Value*16, 255),
                  Min(TGUIScroll(GetControl('scP2Green')).Value*16, 255),
                  Min(TGUIScroll(GetControl('scP2Blue')).Value*16, 255));
end;

procedure ProcSelectModel(Sender: TGUIControl);
var
  a: string;
  window: TGUIWindow;
begin
  window := g_GUI_GetWindow('OptionsPlayersP1Menu');
  a := TGUIListBox(TGUIMenu(window.GetControl('mOptionsPlayersP1Menu')).GetControl('lsP1Model')).SelectedItem;
  if a <> '' then TGUIModelView(window.GetControl('mvP1Model')).SetModel(a);

  window := g_GUI_GetWindow('OptionsPlayersP2Menu');
  a := TGUIListBox(TGUIMenu(window.GetControl('mOptionsPlayersP2Menu')).GetControl('lsP2Model')).SelectedItem;
  if a <> '' then TGUIModelView(window.GetControl('mvP2Model')).SetModel(a);

  ProcChangeColor(nil);
end;

procedure MenuLoadData();
begin
  e_WriteLog('Loading menu data...', TMsgType.Notify);

  g_Texture_CreateWADEx('MAINMENU_LOGO', GameWAD+':TEXTURES\MAINLOGO');
  g_Texture_CreateWADEx('MAINMENU_MARKER1', GameWAD+':TEXTURES\MARKER1');
  g_Texture_CreateWADEx('MAINMENU_MARKER2', GameWAD+':TEXTURES\MARKER2');
  g_Texture_CreateWADEx('SCROLL_LEFT', GameWAD+':TEXTURES\SLEFT');
  g_Texture_CreateWADEx('SCROLL_RIGHT', GameWAD+':TEXTURES\SRIGHT');
  g_Texture_CreateWADEx('SCROLL_MIDDLE', GameWAD+':TEXTURES\SMIDDLE');
  g_Texture_CreateWADEx('SCROLL_MARKER', GameWAD+':TEXTURES\SMARKER');
  g_Texture_CreateWADEx('EDIT_LEFT', GameWAD+':TEXTURES\ELEFT');
  g_Texture_CreateWADEx('EDIT_RIGHT', GameWAD+':TEXTURES\ERIGHT');
  g_Texture_CreateWADEx('EDIT_MIDDLE', GameWAD+':TEXTURES\EMIDDLE');
  g_Texture_CreateWADEx('BOX1', GameWAD+':TEXTURES\BOX1');
  g_Texture_CreateWADEx('BOX2', GameWAD+':TEXTURES\BOX2');
  g_Texture_CreateWADEx('BOX3', GameWAD+':TEXTURES\BOX3');
  g_Texture_CreateWADEx('BOX4', GameWAD+':TEXTURES\BOX4');
  g_Texture_CreateWADEx('BOX5', GameWAD+':TEXTURES\BOX5');
  g_Texture_CreateWADEx('BOX6', GameWAD+':TEXTURES\BOX6');
  g_Texture_CreateWADEx('BOX7', GameWAD+':TEXTURES\BOX7');
  g_Texture_CreateWADEx('BOX8', GameWAD+':TEXTURES\BOX8');
  g_Texture_CreateWADEx('BOX9', GameWAD+':TEXTURES\BOX9');
  g_Texture_CreateWADEx('BSCROLL_UP_A', GameWAD+':TEXTURES\SCROLLUPA');
  g_Texture_CreateWADEx('BSCROLL_UP_U', GameWAD+':TEXTURES\SCROLLUPU');
  g_Texture_CreateWADEx('BSCROLL_DOWN_A', GameWAD+':TEXTURES\SCROLLDOWNA');
  g_Texture_CreateWADEx('BSCROLL_DOWN_U', GameWAD+':TEXTURES\SCROLLDOWNU');
  g_Texture_CreateWADEx('BSCROLL_MIDDLE', GameWAD+':TEXTURES\SCROLLMIDDLE');
  g_Texture_CreateWADEx('NOPIC', GameWAD+':TEXTURES\NOPIC');

  g_Sound_CreateWADEx('MENU_SELECT', GameWAD+':SOUNDS\MENUSELECT');
  g_Sound_CreateWADEx('MENU_OPEN', GameWAD+':SOUNDS\MENUOPEN');
  g_Sound_CreateWADEx('MENU_CLOSE', GameWAD+':SOUNDS\MENUCLOSE');
  g_Sound_CreateWADEx('MENU_CHANGE', GameWAD+':SOUNDS\MENUCHANGE');
  g_Sound_CreateWADEx('SCROLL_ADD', GameWAD+':SOUNDS\SCROLLADD');
  g_Sound_CreateWADEx('SCROLL_SUB', GameWAD+':SOUNDS\SCROLLSUB');
  g_Sound_CreateWADEx('SOUND_PLAYER_FALL', GameWAD+':SOUNDS\FALL');
end;

procedure MenuFreeData();
begin
  e_CharFont_Remove(gMenuFont);
  e_CharFont_Remove(gMenuSmallFont);

  g_Texture_Delete('MAINMENU_LOGO');
  g_Texture_Delete('MAINMENU_MARKER1');
  g_Texture_Delete('MAINMENU_MARKER2');
  g_Texture_Delete('SCROLL_LEFT');
  g_Texture_Delete('SCROLL_RIGHT');
  g_Texture_Delete('SCROLL_MIDDLE');
  g_Texture_Delete('SCROLL_MARKER');
  g_Texture_Delete('EDIT_LEFT');
  g_Texture_Delete('EDIT_RIGHT');
  g_Texture_Delete('EDIT_MIDDLE');
  g_Texture_Delete('BOX1');
  g_Texture_Delete('BOX2');
  g_Texture_Delete('BOX3');
  g_Texture_Delete('BOX4');
  g_Texture_Delete('BOX5');
  g_Texture_Delete('BOX6');
  g_Texture_Delete('BOX7');
  g_Texture_Delete('BOX8');
  g_Texture_Delete('BOX9');
  g_Texture_Delete('BSCROLL_UP_A');
  g_Texture_Delete('BSCROLL_UP_U');
  g_Texture_Delete('BSCROLL_DOWN_A');
  g_Texture_Delete('BSCROLL_DOWN_U');
  g_Texture_Delete('BSCROLL_MIDDLE');
  g_Texture_Delete('NOPIC');

  g_Sound_Delete('MENU_SELECT');
  g_Sound_Delete('MENU_OPEN');
  g_Sound_Delete('MENU_CLOSE');
  g_Sound_Delete('MENU_CHANGE');
  g_Sound_Delete('SCROLL_ADD');
  g_Sound_Delete('SCROLL_SUB');
  g_Sound_Delete('SOUND_PLAYER_FALL');
end;

procedure ProcAuthorsMenu();
begin
  gMusic.SetByName('MUSIC_INTERMUS');
  gMusic.Play();
end;

procedure ProcExitMenuKeyDown (yes: Boolean);
var
  s: ShortString;
  snd: TPlayableSound;
  res: Boolean;
begin
  if yes then
  begin
    g_Game_StopAllSounds(True);
    case (Random(18)) of
      0: s := 'SOUND_MONSTER_PAIN';
      1: s := 'SOUND_MONSTER_DIE_3';
      2: s := 'SOUND_MONSTER_SLOP';
      3: s := 'SOUND_MONSTER_DEMON_DIE';
      4: s := 'SOUND_MONSTER_IMP_DIE_2';
      5: s := 'SOUND_MONSTER_MAN_DIE';
      6: s := 'SOUND_MONSTER_BSP_DIE';
      7: s := 'SOUND_MONSTER_VILE_DIE';
      8: s := 'SOUND_MONSTER_SKEL_DIE';
      9: s := 'SOUND_MONSTER_MANCUB_ALERT';
      10: s := 'SOUND_MONSTER_PAIN_PAIN';
      11: s := 'SOUND_MONSTER_BARON_DIE';
      12: s := 'SOUND_MONSTER_CACO_DIE';
      13: s := 'SOUND_MONSTER_CYBER_DIE';
      14: s := 'SOUND_MONSTER_KNIGHT_ALERT';
      15: s := 'SOUND_MONSTER_SPIDER_ALERT';
      else s := 'SOUND_PLAYER_FALL';
    end;
    snd := TPlayableSound.Create();
    res := snd.SetByName(s);
    if not res then res := snd.SetByName('SOUND_PLAYER_FALL');
    if res then
    begin
      snd.Play(True);
      while snd.IsPlaying() do begin end;
    end;
    g_Game_Quit();
    exit;
  end;
  g_GUI_HideWindow();
end;

procedure ProcLoadMenu();
var
  a: Integer;
  valid: Boolean;
begin
  for a := 1 to 8 do
  begin
    TGUIEdit(TGUIMenu(g_GUI_GetWindow('LoadMenu').GetControl('mmLoadMenu')).GetControl('edSlot'+IntToStr(a))).Text := g_GetSaveName(a, valid);
    TGUIEdit(TGUIMenu(g_GUI_GetWindow('LoadMenu').GetControl('mmLoadMenu')).GetControl('edSlot'+IntToStr(a))).Invalid := not valid;
    //TGUIMenu(g_GUI_GetWindow('LoadMenu').GetControl('mmLoadMenu')).GetControl('edSlot'+IntToStr(a)).Enabled := valid;
  end;
end;

procedure ProcSaveMenu();
var
  a: Integer;
  valid: Boolean;
  name: AnsiString;
begin
  for a := 1 to 8 do
  begin
    name := g_GetSaveName(a, valid);
    TGUIEdit(TGUIMenu(g_GUI_GetWindow('SaveMenu').GetControl('mmSaveMenu')).GetControl('edSlot'+IntToStr(a))).Text := name;
    TGUIEdit(TGUIMenu(g_GUI_GetWindow('SaveMenu').GetControl('mmSaveMenu')).GetControl('edSlot'+IntToStr(a))).Invalid := (name <> '') and (not valid);
  end;
end;

procedure ProcSaveGame(Sender: TGUIControl);
var
  a: Integer;
begin
  if g_Game_IsNet then Exit;
  if g_Game_IsTestMap then Exit;
  a := StrToInt(Copy(Sender.Name, Length(Sender.Name), 1));
  g_Game_PauseAllSounds(True);
  g_SaveGame(a, TGUIEdit(Sender).Text);

  g_ActiveWindow := nil;
  g_Game_Pause(False);
end;

procedure ProcLoadGame(Sender: TGUIControl);
var
  a: Integer;
begin
  if g_Game_IsNet then Exit;
  a := StrToInt(Copy(Sender.Name, Length(Sender.Name), 1));
  if g_LoadGame(a) then
  begin
    g_Game_PauseAllSounds(False)
  end
  else // �� ����������� - ������� � ����
  begin
    g_Console_Add(_lc[I_MSG_BAD_SAVE_VERSION], true);
    g_GUI_GetWindow('LoadMenu').SetActive(g_GUI_GetWindow('LoadMenu').GetControl('mmLoadMenu'));
    //g_ActiveWindow := nil;
  end;
end;

procedure ProcSinglePlayer (n: Integer);
  var wad, map: AnsiString;
begin
  assert(n >= 1);
  wad := g_ExtractWadName(gDefaultMegawadStart);
  map := g_ExtractFilePathName(gDefaultMegawadStart);
  if e_FindResource(AllMapDirs, wad) then
  begin
    wad := ExpandFileName(wad);
    g_Game_StartSingle(wad + ':\' + map, n > 1, n)
  end
end;

procedure ProcSingle1Player;
begin
  ProcSinglePlayer(1)
end;

procedure ProcSingle2Players;
begin
  ProcSinglePlayer(2)
end;

procedure ProcSelectMapMenu();
var
  menu: TGUIMenu;
  wad_lb: TGUIFileListBox;
  map_lb: TGUIListBox;
  map: String;
begin
  menu := TGUIMenu(g_GUI_GetWindow('SelectMapMenu').GetControl('mSelectMapMenu'));
  wad_lb := TGUIFileListBox(menu.GetControl('lsMapWAD'));
  map_lb := TGUIListBox(menu.GetControl('lsMapRes'));

  if wad_lb.SelectedItem() <> '' then
    map := map_lb.SelectedItem()
  else
    map := '';

  wad_lb.UpdateFileList();
  map_lb.Clear();

  if wad_lb.SelectedItem() <> '' then
  begin
    ProcSelectWAD(nil);
    map_lb.SelectItem(map);

    if map_lb.SelectedItem() <> '' then
      ProcSelectMap(nil);
  end;

  g_GUI_ShowWindow('SelectMapMenu');
end;

procedure ProcSelectCampaignMenu();
var
  menu: TGUIMenu;
  wad_lb: TGUIFileListBox;
begin
  menu := TGUIMenu(g_GUI_GetWindow('CampaignMenu').GetControl('mCampaignMenu'));
  wad_lb := TGUIFileListBox(menu.GetControl('lsWAD'));

  wad_lb.UpdateFileList();

  if wad_lb.SelectedItem() <> '' then
    ProcSelectCampaignWAD(nil);
end;

procedure ProcSetMap();
var
  wad, map, res: String;
begin
  with TGUIMenu(g_ActiveWindow.GetControl('mSelectMapMenu')) do
  begin
    wad := TGUIFileListBox(GetControl('lsMapWAD')).SelectedItem();
    map := TGUIListBox(GetControl('lsMapRes')).SelectedItem();
  end;

  if (wad = '') or (map = '') then
    Exit;

  wad := e_FindWadRel(MapDirs, WAD);

  res := wad+':\'+map;

  TGUILabel(TGUIMenu(g_GUI_GetWindow('CustomGameMenu').GetControl('mCustomGameMenu')).GetControl('lbMap')).Text := res;
  TGUILabel(TGUIMenu(g_GUI_GetWindow('NetServerMenu').GetControl('mNetServerMenu')).GetControl('lbMap')).Text := res;
end;

procedure ProcChangeSoundSettings(Sender: TGUIControl);
var
  menu: TGUIMenu;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsSoundMenu').GetControl('mOptionsSoundMenu'));

  g_Sound_SetupAllVolumes(
    Min(TGUIScroll(menu.GetControl('scSoundLevel')).Value*16, 255),
    Min(TGUIScroll(menu.GetControl('scMusicLevel')).Value*16, 255)
  );
end;

procedure ProcChangeGameSettings(Sender: TGUIControl);
var
  menu: TGUIMenu;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsGameMenu').GetControl('mOptionsGameMenu'));
  if TGUIScroll(menu.GetControl('scScaleFactor')).Value <> TempScale then
  begin
    TempScale := TGUIScroll(menu.GetControl('scScaleFactor')).Value;
    g_dbg_scale := TempScale + 1;
  end;
end;

procedure ProcChangeTouchSettings(Sender: TGUIControl);
var
  menu: TGUIMenu;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsControlsTouchMenu').GetControl('mOptionsControlsTouchMenu'));
  g_touch_alt := TGUISwitch(menu.GetControl('swTouchAlt')).ItemIndex = 1;
  g_touch_size := TGUIScroll(menu.GetControl('scTouchSize')).Value / 10 + 0.5;
  g_touch_offset := TGUIScroll(menu.GetControl('scTouchOffset')).Value * 5;
end;

procedure ProcOptionsPlayersMIMenu();
var
  s, a: string;
  i: Integer;
begin
  if g_ActiveWindow.Name = 'OptionsPlayersP1Menu' then s := 'P1' else s := 'P2';

  a := TGUIListBox(TGUIMenu(g_ActiveWindow.GetControl('mOptionsPlayers'+s+'Menu')).GetControl('ls'+s+'Model')).SelectedItem;

  if a = '' then Exit;

  i := g_PlayerModel_GetIndex(a);
  with TGUIMenu(g_GUI_GetWindow('OptionsPlayersMIMenu').GetControl('mOptionsPlayersMIMenu')) do
  begin
    TGUILabel(GetControl('lbName')).Text := PlayerModelsArray[i].Name;
    TGUILabel(GetControl('lbAuthor')).Text := PlayerModelsArray[i].Author;
    TGUIMemo(GetControl('meComment')).SetText(PlayerModelsArray[i].Description);

    if PlayerModelsArray[i].HaveWeapon then
      TGUILabel(GetControl('lbWeapon')).Text := _lc[I_MENU_YES]
    else
      TGUILabel(GetControl('lbWeapon')).Text := _lc[I_MENU_NO];
  end;

  g_GUI_ShowWindow('OptionsPlayersMIMenu');
end;

procedure ProcOptionsPlayerP1WeaponMenu();
var
  a: string;
begin
  a := TGUIListBox(TGUIMenu(g_ActiveWindow.GetControl('mOptionsPlayers'+'P1'+'Menu')).GetControl('ls'+'P1'+'Model')).SelectedItem;
  if a = '' then Exit;
  g_GUI_ShowWindow('OptionsPlayersP1WeaponMenu');
end;

procedure ProcOptionsPlayerP1WeaponPreferencesMenu();
begin
  g_GUI_ShowWindow('OptionsPreferencesP1WeaponMenu');
end;

procedure ProcOptionsPlayerP2WeaponMenu();
var
  a: string;
begin
  a := TGUIListBox(TGUIMenu(g_ActiveWindow.GetControl('mOptionsPlayers'+'P2'+'Menu')).GetControl('ls'+'P2'+'Model')).SelectedItem;
  if a = '' then Exit;
  g_GUI_ShowWindow('OptionsPlayersP2WeaponMenu');
end;

procedure ProcOptionsPlayerP2WeaponPreferencesMenu();
begin
  g_GUI_ShowWindow('OptionsPreferencesP2WeaponMenu');
end;

procedure ProcOptionsPlayersAnim();
var
  s: String;
begin
  if g_ActiveWindow.Name = 'OptionsPlayersP1Menu' then
    s := 'P1'
  else
    s := 'P2';

  with TGUIModelView(g_ActiveWindow.GetControl('mv'+s+'Model')) do
  begin
    NextAnim();
    Model.AnimState.Loop := True;
  end;
end;

procedure ProcOptionsPlayersWeap();
var
  s: String;
begin
  if g_ActiveWindow.Name = 'OptionsPlayersP1Menu' then
    s := 'P1'
  else
    s := 'P2';

  with TGUIModelView(g_ActiveWindow.GetControl('mv'+s+'Model')) do
    NextWeapon();
end;

procedure ProcOptionsPlayersRot();
var
  s: string;
begin
  if g_ActiveWindow.Name = 'OptionsPlayersP1Menu' then s := 'P1' else s := 'P2';
  with TGUIModelView(g_ActiveWindow.GetControl('mv'+s+'Model')).Model do
  begin
    if Direction = TDirection.D_LEFT then Direction := TDirection.D_RIGHT else Direction := TDirection.D_LEFT;
  end;
end;

procedure ProcDefaultMenuKeyDown (yes: Boolean);
begin
  if yes then
  begin
    g_Options_SetDefault();
    ReadOptions();
  end;
  g_GUI_HideWindow();
end;

procedure ProcSavedMenuKeyDown (yes: Boolean);
begin
  if yes then ReadOptions();
  g_GUI_HideWindow();
end;

procedure ProcAuthorsClose();
begin
  gMusic.SetByName('MUSIC_MENU');
  gMusic.Play();
  gState := STATE_MENU;
end;

procedure ProcGMClose();
begin
  g_Game_InGameMenu(False);
end;

procedure ProcGMShow();
var
  Enabled: Boolean;
begin
  Enabled := True;
  if (gGameSettings.GameType = GT_SINGLE) and
     ((gPlayer1 = nil) or (not gPlayer1.alive)) and
     ((gPlayer2 = nil) or (not gPlayer2.alive)) then
    Enabled := False; // ���� �� ������� ����� � ������
  if not gGameOn then
    Enabled := False; // ��������� ���������� � ����������� (�� �����������)
  if g_Game_IsTestMap then
    Enabled := False; // ���� ������ �� �������� ��� ��������� �����
  TGUIMainMenu(g_ActiveWindow.GetControl(
    g_ActiveWindow.DefControl )).EnableButton('save', Enabled);
end;

procedure ProcChangePlayers();
var
  TeamGame, Spectator, AddTwo: Boolean;
  P1Team{, P2Team}: Byte;
  bP2: TGUITextButton;
begin
  TeamGame := gGameSettings.GameMode in [GM_TDM, GM_CTF];
  Spectator := (gPlayer1 = nil) and (gPlayer2 = nil);
  AddTwo := gGameSettings.GameType in [GT_CUSTOM, GT_SERVER];
  P1Team := TEAM_NONE;
  if gPlayer1 <> nil then P1Team := gPlayer1.Team;
  // TODO
  //P2Team := TEAM_NONE;
  //if gPlayer2 <> nil then P2Team := gPlayer2.Team;

  TGUIMainMenu(g_ActiveWindow.GetControl(
    g_ActiveWindow.DefControl )).EnableButton('tmJoinRed', TeamGame and (P1Team <> TEAM_RED));
  TGUIMainMenu(g_ActiveWindow.GetControl(
    g_ActiveWindow.DefControl )).EnableButton('tmJoinBlue', TeamGame and (P1Team <> TEAM_BLUE));
  TGUIMainMenu(g_ActiveWindow.GetControl(
    g_ActiveWindow.DefControl )).EnableButton('tmJoinGame', Spectator and not TeamGame);

  bP2 := TGUIMainMenu(g_ActiveWindow.GetControl(
    g_ActiveWindow.DefControl )).GetButton('tmPlayer2');
  bP2.Enabled := AddTwo and not Spectator;
  if bP2.Enabled then
    bP2.Color := MAINMENU_ITEMS_COLOR
  else
    bP2.Color := MAINMENU_UNACTIVEITEMS_COLOR;
  if gPlayer2 = nil then
    bP2.Caption := _lc[I_MENU_ADD_PLAYER_2]
  else
    bP2.Caption := _lc[I_MENU_REM_PLAYER_2];

  TGUIMainMenu(g_ActiveWindow.GetControl(
    g_ActiveWindow.DefControl )).EnableButton('tmSpectate', not Spectator);
end;

procedure ProcJoinRed();
begin
  if not (gGameSettings.GameType in [GT_CUSTOM, GT_SERVER, GT_CLIENT]) then
    Exit;
  if g_Game_IsServer then
  begin
    if gPlayer1 = nil then
      g_Game_AddPlayer(TEAM_RED)
    else
    begin
      if gPlayer1.Team <> TEAM_RED then
      begin
        gPlayer1.SwitchTeam;
        gPlayer1Settings.Team := gPlayer1.Team;
      end;

      if g_Game_IsNet then MH_SEND_PlayerSettings(gPlayer1.UID);
    end;
  end
  else
  begin
    gPlayer1Settings.Team := TEAM_RED;
    MC_SEND_PlayerSettings;
    if gPlayer1 = nil then
      g_Game_AddPlayer(TEAM_RED);
  end;
  g_ActiveWindow := nil;
  g_Game_Pause(False);
end;

procedure ProcJoinBlue();
begin
  if not (gGameSettings.GameType in [GT_CUSTOM, GT_SERVER, GT_CLIENT]) then
    Exit;
  if g_Game_IsServer then
  begin
    if gPlayer1 = nil then
      g_Game_AddPlayer(TEAM_BLUE)
    else
    begin
      if gPlayer1.Team <> TEAM_BLUE then
      begin
        gPlayer1.SwitchTeam;
        gPlayer1Settings.Team := gPlayer1.Team;
      end;

      if g_Game_IsNet then MH_SEND_PlayerSettings(gPlayer1.UID);
    end;
  end
  else
  begin
    gPlayer1Settings.Team := TEAM_BLUE;
    MC_SEND_PlayerSettings;
    if gPlayer1 = nil then
      g_Game_AddPlayer(TEAM_BLUE);
  end;
  g_ActiveWindow := nil;
  g_Game_Pause(False);
end;

procedure ProcJoinGame();
begin
  if not (gGameSettings.GameType in [GT_CUSTOM, GT_SERVER, GT_CLIENT]) then
    Exit;
  if gPlayer1 = nil then
    g_Game_AddPlayer();
  g_ActiveWindow := nil;
  g_Game_Pause(False);
end;

procedure ProcSwitchP2();
begin
  if not (gGameSettings.GameType in [GT_CUSTOM, GT_SERVER]) then
    Exit;
  if gPlayer1 = nil then
    Exit;
  if gPlayer2 = nil then
    g_Game_AddPlayer()
  else
    g_Game_RemovePlayer();
  g_ActiveWindow := nil;
  g_Game_Pause(False);
end;

procedure ProcSpectate();
begin
  if not (gGameSettings.GameType in [GT_CUSTOM, GT_SERVER, GT_CLIENT]) then
    Exit;
  g_Game_Spectate();
  g_ActiveWindow := nil;
  g_Game_Pause(False);
end;

procedure ProcRestartMenuKeyDown (yes: Boolean);
begin
  if yes then g_Game_Restart() else g_GUI_HideWindow;
end;

procedure ProcEndMenuKeyDown (yes: Boolean);
begin
  if yes then gExit := EXIT_SIMPLE else g_GUI_HideWindow;
end;

procedure ProcSetRussianLanguage;
begin
  if gLanguage <> LANGUAGE_RUSSIAN then
  begin
    gLanguage := LANGUAGE_RUSSIAN;
    gLanguageChange := True;
    gAskLanguage := False;
    ProcApplyOptions();
  end;
end;

procedure ProcSetEnglishLanguage;
begin
  if gLanguage <> LANGUAGE_ENGLISH then
  begin
    gLanguage := LANGUAGE_ENGLISH;
    gLanguageChange := True;
    gAskLanguage := False;
    ProcApplyOptions();
  end;
end;

procedure ReadGameSettings();
var
  menu: TGUIMenu;
begin
  menu := TGUIMenu(g_GUI_GetWindow('GameSetGameMenu').GetControl('mGameSetGameMenu'));

  with gGameSettings do
  begin
    with TGUISwitch(menu.GetControl('swTeamDamage')) do
      if LongBool(Options and GAME_OPTION_TEAMDAMAGE) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    with TGUISwitch(menu.GetControl('swTeamHit')) do
      if (Options and (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE)) = (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE) then
        ItemIndex := 0
      else if LongBool(Options and GAME_OPTION_TEAMHITTRACE) then
        ItemIndex := 1
      else if LongBool(Options and GAME_OPTION_TEAMHITPROJECTILE) then
        ItemIndex := 2
      else
        ItemIndex := 3;
    with TGUISwitch(menu.GetControl('swDeathmatchKeys')) do
      if LongBool(Options and GAME_OPTION_DMKEYS) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    with TGUISwitch(menu.GetControl('swFlagDrop')) do
      if LongBool(Options and GAME_OPTION_ALLOWDROPFLAG) and LongBool(Options and GAME_OPTION_THROWFLAG) then
        ItemIndex := 0
      else if LongBool(Options and GAME_OPTION_ALLOWDROPFLAG) then
        ItemIndex := 1
      else
        ItemIndex := 2;

    TGUIEdit(menu.GetControl('edTimeLimit')).Text := IntToStr(TimeLimit);
    TGUIEdit(menu.GetControl('edGoalLimit')).Text := IntToStr(GoalLimit);
    TGUIEdit(menu.GetControl('edMaxLives')).Text := IntToStr(MaxLives);

    with TGUISwitch(menu.GetControl('swBotsVS')) do
      if LongBool(Options and GAME_OPTION_BOTVSPLAYER) and
         LongBool(Options and GAME_OPTION_BOTVSMONSTER) then
        ItemIndex := 2
      else
        if LongBool(Options and GAME_OPTION_BOTVSMONSTER) then
          ItemIndex := 1
        else
          ItemIndex := 0;

    if GameType in [GT_CUSTOM, GT_SERVER] then
      begin
        TGUISwitch(menu.GetControl('swTeamDamage')).Enabled := True;
        TGUISwitch(menu.GetControl('swTeamHit')).Enabled := True;
        if (GameMode in [GM_DM, GM_TDM, GM_CTF]) then
        begin
          TGUISwitch(menu.GetControl('swDeathmatchKeys')).Enabled := True;
          TGUILabel(menu.GetControlsText('swDeathmatchKeys')).Color := MENU_ITEMSTEXT_COLOR;
        end
        else
        begin
          TGUISwitch(menu.GetControl('swDeathmatchKeys')).Enabled := False;
          TGUILabel(menu.GetControlsText('swDeathmatchKeys')).Color := MENU_UNACTIVEITEMS_COLOR;
        end;
        TGUIEdit(menu.GetControl('edTimeLimit')).Enabled := True;
        TGUILabel(menu.GetControlsText('edTimeLimit')).Color := MENU_ITEMSTEXT_COLOR;
        TGUIEdit(menu.GetControl('edGoalLimit')).Enabled := True;
        TGUILabel(menu.GetControlsText('edGoalLimit')).Color := MENU_ITEMSTEXT_COLOR;
        TGUIEdit(menu.GetControl('edMaxLives')).Enabled := True;
        TGUILabel(menu.GetControlsText('edMaxLives')).Color := MENU_ITEMSTEXT_COLOR;
        TGUISwitch(menu.GetControl('swBotsVS')).Enabled := True;
        TGUISwitch(menu.GetControl('swFlagDrop')).Enabled := True;
      end
    else
      begin
        TGUISwitch(menu.GetControl('swTeamDamage')).Enabled := True;
        TGUISwitch(menu.GetControl('swTeamHit')).Enabled := True;
        TGUISwitch(menu.GetControl('swDeathmatchKeys')).Enabled := False;
        TGUILabel(menu.GetControlsText('swDeathmatchKeys')).Color := MENU_UNACTIVEITEMS_COLOR;
        with TGUIEdit(menu.GetControl('edTimeLimit')) do
        begin
          Enabled := False;
          Text := '';
        end;
        TGUILabel(menu.GetControlsText('edTimeLimit')).Color := MENU_UNACTIVEITEMS_COLOR;
        with TGUIEdit(menu.GetControl('edGoalLimit')) do
        begin
          Enabled := False;
          Text := '';
        end;
        TGUILabel(menu.GetControlsText('edGoalLimit')).Color := MENU_UNACTIVEITEMS_COLOR;
        with TGUIEdit(menu.GetControl('edMaxLives')) do
        begin
          Enabled := False;
          Text := '';
        end;
        TGUILabel(menu.GetControlsText('edMaxLives')).Color := MENU_UNACTIVEITEMS_COLOR;
        TGUISwitch(menu.GetControl('swBotsVS')).Enabled := True;
        TGUISwitch(menu.GetControl('swFlagDrop')).Enabled := False;
      end;
  end;
end;

procedure ProcApplyGameSet();
var
  menu: TGUIMenu;
  a, b, n: Integer;
  stat: TPlayerStatArray;
begin
  menu := TGUIMenu(g_GUI_GetWindow('GameSetGameMenu').GetControl('mGameSetGameMenu'));

  if not g_Game_IsServer then Exit;

  with gGameSettings do
  begin
    if TGUISwitch(menu.GetControl('swTeamDamage')).Enabled then
    begin
      if TGUISwitch(menu.GetControl('swTeamDamage')).ItemIndex = 0 then
        Options := Options or GAME_OPTION_TEAMDAMAGE
      else
        Options := Options and (not GAME_OPTION_TEAMDAMAGE);
    end;

    if TGUISwitch(menu.GetControl('swTeamHit')).Enabled then
    begin
      Options := Options and not (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE);
      case TGUISwitch(menu.GetControl('swTeamHit')).ItemIndex of
        1: Options := Options or GAME_OPTION_TEAMHITTRACE;
        2: Options := Options or GAME_OPTION_TEAMHITPROJECTILE;
        0: Options := Options or GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE;
      end;
    end;

    if TGUISwitch(menu.GetControl('swDeathmatchKeys')).Enabled then
    begin
      if TGUISwitch(menu.GetControl('swDeathmatchKeys')).ItemIndex = 0 then
        Options := Options or GAME_OPTION_DMKEYS
      else
        Options := Options and (not GAME_OPTION_DMKEYS);
    end;

    if TGUIEdit(menu.GetControl('edTimeLimit')).Enabled then
    begin
      n := StrToIntDef(TGUIEdit(menu.GetControl('edTimeLimit')).Text, TimeLimit);

      if n = 0 then
        TimeLimit := 0
      else
        begin
          b := (gTime - gGameStartTime) div 1000 + 10; // 10 ������ �� �����

          TimeLimit := Max(n, b);
        end;
    end;

    if TGUIEdit(menu.GetControl('edGoalLimit')).Enabled then
    begin
      n := StrToIntDef(TGUIEdit(menu.GetControl('edGoalLimit')).Text, GoalLimit);

      if n = 0 then
        GoalLimit := 0
      else
        begin
          b := 0;
          if GameMode = GM_DM then
            begin // DM
              stat := g_Player_GetStats();
              if stat <> nil then
                for a := 0 to High(stat) do
                  if stat[a].Frags > b then
                    b := stat[a].Frags;
            end
          else // CTF
            b := Max(gTeamStat[TEAM_RED].Goals, gTeamStat[TEAM_BLUE].Goals);

          GoalLimit := Max(n, b);
        end;
    end;

    if TGUIEdit(menu.GetControl('edMaxLives')).Enabled then
    begin
      n := StrToIntDef(TGUIEdit(menu.GetControl('edMaxLives')).Text, GoalLimit);
      if n < 0 then n := 0;
      if n > 255 then n := 255;
      if n = 0 then
        MaxLives := 0
      else
        begin
          b := 0;
          stat := g_Player_GetStats();
          if stat <> nil then
            for a := 0 to High(stat) do
              if stat[a].Lives > b then
                b := stat[a].Lives;

          MaxLives := Max(n, b);
        end;
    end;

    if TGUISwitch(menu.GetControl('swBotsVS')).Enabled then
    begin
      case TGUISwitch(menu.GetControl('swBotsVS')).ItemIndex of
        1:
          begin
            Options := Options and (not GAME_OPTION_BOTVSPLAYER);
            Options := Options or GAME_OPTION_BOTVSMONSTER;
          end;
        2:
          begin
            Options := Options or GAME_OPTION_BOTVSPLAYER;
            Options := Options or GAME_OPTION_BOTVSMONSTER;
          end;
        else
          begin
            Options := Options or GAME_OPTION_BOTVSPLAYER;
            Options := Options and (not GAME_OPTION_BOTVSMONSTER);
          end;
      end;
    end;

    if TGUISwitch(menu.GetControl('swFlagDrop')).Enabled then
    begin
      case TGUISwitch(menu.GetControl('swFlagDrop')).ItemIndex of
        0: Options := Options or GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG;
        1: Options := Options or GAME_OPTION_ALLOWDROPFLAG;
        else Options := Options and not (GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG);
      end;
    end;

    // don't forget to latch this shit
    gsGameFlags := Options;
    gsMaxLives := MaxLives;
    gsGoalLimit := GoalLimit;
    gsTimeLimit := TimeLimit;
  end;

  if g_Game_IsNet then MH_SEND_GameSettings;
end;

procedure ProcVideoOptionsRes();
var
  menu: TGUIMenu;
  list: SSArray;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsVideoResMenu').GetControl('mOptionsVideoResMenu'));

  TGUILabel(menu.GetControl('lbCurrentRes')).Text :=
    IntToStr(gWinSizeX) +
    ' x ' + IntToStr(gWinSizeY) +
    ', ' + IntToStr(gBPP) + ' bpp';

  with TGUIListBox(menu.GetControl('lsResolution')) do
  begin
    list := sys_GetDisplayModes(gBPP);
    if list <> nil then
    begin
      Items := list;
      ItemIndex := Length(list)
    end
    else
    begin
      Clear
    end
  end;

  with TGUISwitch(menu.GetControl('swFullScreen')) do
    if gFullscreen then
      ItemIndex := 0
    else
      ItemIndex := 1;

  TempResScale := Round(r_pixel_scale - 1);
  with TGUISwitch(menu.GetControl('swResFactor')) do
    ItemIndex := Min(TempResScale, gRC_Width div 640 - 1);
end;

procedure ProcApplyVideoOptions();
var
  menu: TGUIMenu;
  Fullscreen: Boolean;
  SWidth, SHeight: Integer;
  ScaleChanged: Boolean;
  str: String;
begin
  menu := TGUIMenu(g_GUI_GetWindow('OptionsVideoResMenu').GetControl('mOptionsVideoResMenu'));

  str := TGUIListBox(menu.GetControl('lsResolution')).SelectedItem;
  if str <> '' then
    SScanf(str, '%dx%d', [@SWidth, @SHeight])
  else
  begin
    SWidth := gWinSizeX;
    SHeight := gWinSizeY;
    TempResScale := Min(TempResScale, SWidth div 640 - 1);
  end;

  Fullscreen := TGUISwitch(menu.GetControl('swFullScreen')).ItemIndex = 0;

  ScaleChanged := False;
  if TGUISwitch(menu.GetControl('swResFactor')).ItemIndex <> TempResScale then
  begin
    TempResScale := Min(TGUISwitch(menu.GetControl('swResFactor')).ItemIndex, SWidth div 640 - 1);
    r_pixel_scale := TempResScale + 1;
    ScaleChanged := True;
  end;

  if (SWidth <> gWinSizeX) or
     (SHeight <> gWinSizeY) or
     (Fullscreen <> gFullscreen) or
     ScaleChanged then
  begin
    gResolutionChange := True;
    gRC_Width := SWidth;
    gRC_Height := SHeight;
    gRC_FullScreen := Fullscreen;
    gRC_Maximized := gWinMaximized;
  end;

// ��������� ��������� ���� ��������:
  ProcApplyOptions();
end;

procedure ProcSetFirstRussianLanguage;
begin
  gLanguage := LANGUAGE_RUSSIAN;
  gLanguageChange := True;
  gAskLanguage := False;
end;

procedure ProcSetFirstEnglishLanguage;
begin
  gLanguage := LANGUAGE_ENGLISH;
  gLanguageChange := True;
  gAskLanguage := False;
end;

procedure ProcRecallAddress();
begin
  with TGUIMenu(g_GUI_GetWindow('NetClientMenu').GetControl('mNetClientMenu')) do
  begin
    TGUIEdit(GetControl('edIP')).Text := NetClientIP;
    TGUIEdit(GetControl('edPort')).Text := IntToStr(NetClientPort);
  end;
end;

procedure CreateFirstLanguageMenu();
var
  Menu: TGUIWindow;
begin
  Menu := TGUIWindow.Create('FirstLanguageMenu');

  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', ' '))) do
  begin
    Name := 'mmFirstLanguageMenu';
    AddButton(@ProcSetFirstRussianLanguage, '�������', '');
    AddButton(@ProcSetFirstEnglishLanguage, 'English', '');
  end;

  Menu.DefControl := 'mmFirstLanguageMenu';
  Menu.MainWindow := True;
  g_GUI_AddWindow(Menu);
end;

procedure g_Menu_AskLanguage();
begin
  CreateFirstLanguageMenu();
  g_GUI_ShowWindow('FirstLanguageMenu');
end;

procedure CreatePlayerOptionsMenu(s: String);
var
  Menu: TGUIWindow;
  a: String;
begin
  Menu := TGUIWindow.Create('OptionsPlayers'+s+'Menu');
  if s = 'P1' then
    a := _lc[I_MENU_PLAYER_1]
  else
    a := _lc[I_MENU_PLAYER_2];
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, a))) do
  begin
    Name := 'mOptionsPlayers'+s+'Menu';
    with AddEdit(_lc[I_MENU_PLAYER_NAME]) do
    begin
      Name := 'ed'+s+'Name';
      MaxLength := 12;
      Width := 12;
    end;
    with AddSwitch(_lc[I_MENU_PLAYER_TEAM]) do
    begin
      Name := 'sw'+s+'Team';
      AddItem(_lc[I_MENU_PLAYER_TEAM_RED]);
      AddItem(_lc[I_MENU_PLAYER_TEAM_BLUE]);
    end ;
    with AddList(_lc[I_MENU_PLAYER_MODEL], 12, 6) do
    begin
      Name := 'ls'+s+'Model';
      Sort := True;
      Items := g_PlayerModel_GetNames();
      OnChange := ProcSelectModel;
    end;
    with AddScroll(_lc[I_MENU_PLAYER_RED]) do
    begin
      Name := 'sc'+s+'Red';
      Max := 16;
      OnChange := ProcChangeColor;
    end;
    with AddScroll(_lc[I_MENU_PLAYER_GREEN]) do
    begin
      Name := 'sc'+s+'Green';
      Max := 16;
      OnChange := ProcChangeColor;
    end;
    with AddScroll(_lc[I_MENU_PLAYER_BLUE]) do
    begin
      Name := 'sc'+s+'Blue';
      Max := 16;
      OnChange := ProcChangeColor;
    end;
    AddSpace();
    AddButton(@ProcOptionsPlayersMIMenu, _lc[I_MENU_MODEL_INFO]);
    AddButton(@ProcOptionsPlayersAnim, _lc[I_MENU_MODEL_ANIMATION]);
    AddButton(@ProcOptionsPlayersWeap, _lc[I_MENU_MODEL_CHANGE_WEAPON]);
    AddButton(@ProcOptionsPlayersRot, _lc[I_MENU_MODEL_ROTATE]);
    if s = 'P1' then AddButton(@ProcOptionsPlayerP1WeaponMenu, _lc[I_MENU_WEAPON])
    else AddButton(@ProcOptionsPlayerP2WeaponMenu, _lc[I_MENU_WEAPON]);
    with TGUIModelView(Menu.AddChild(TGUIModelView.Create)) do
    begin
      Name := 'mv'+s+'Model';
      X := GetControl('ls'+s+'Model').X+TGUIListBox(GetControl('ls'+s+'Model')).GetWidth+16;
      Y := GetControl('ls'+s+'Model').Y;
    end;
  end;
  Menu.DefControl := 'mOptionsPlayers'+s+'Menu';
  g_GUI_AddWindow(Menu);
end;

procedure CreateAllMenus();
var
  Menu: TGUIWindow;
  //SR: TSearchRec;
  a, cx, _y, i: Integer;
  //list: SSArray;
begin
  Menu := TGUIWindow.Create('MainMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, 'MAINMENU_LOGO', _lc[I_MENU_MAIN_MENU]))) do
  begin
    Name := 'mmMainMenu';
    AddButton(nil, _lc[I_MENU_NEW_GAME], 'NewGameMenu');
    AddButton(nil, _lc[I_MENU_MULTIPLAYER], 'NetGameMenu');
    AddButton(nil, _lc[I_MENU_LOAD_GAME], 'LoadMenu');
    AddButton(@ReadOptions, _lc[I_MENU_OPTIONS], 'OptionsMenu');
    AddButton(@ProcAuthorsMenu, _lc[I_MENU_AUTHORS], 'AuthorsMenu');
    AddButton(nil, _lc[I_MENU_EXIT], 'ExitMenu');
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(Format(_lc[I_VERSION], [GAME_VERSION]), gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := gScreenWidth-GetWidth-8;
    Y := gScreenHeight-GetHeight-8;
  end;
  Menu.DefControl := 'mmMainMenu';
  Menu.MainWindow := True;
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('NewGameMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_NEW_GAME]))) do
  begin
    Name := 'mmNewGameMenu';
    AddButton(@ProcSingle1Player, _lc[I_MENU_1_PLAYER]);
    AddButton(@ProcSingle2Players, _lc[I_MENU_2_PLAYERS]);
    AddButton(@ProcSelectCampaignMenu, _lc[I_MENU_CAMPAIGN], 'CampaignMenu');
    AddButton(nil, _lc[I_MENU_CUSTOM_GAME], 'CustomGameMenu');
  end;
  Menu.DefControl := 'mmNewGameMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('NetGameMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_MULTIPLAYER]))) do
  begin
    Name := 'mmNetGameMenu';
    AddButton(@ProcRecallAddress, _lc[I_MENU_START_CLIENT], 'NetClientMenu');
    AddButton(nil, _lc[I_MENU_START_SERVER], 'NetServerMenu');
  end;
  Menu.DefControl := 'mmNetGameMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('NetServerMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_START_SERVER]))) do
  begin
    Name := 'mNetServerMenu';
    with AddEdit(_lc[I_NET_SERVER_NAME]) do
    begin
      Name := 'edSrvName';
      OnlyDigits := False;
      Width := 16;
      MaxLength := 64;
      Text := NetServerName;
    end;
    with AddEdit(_lc[I_NET_SERVER_PASSWORD]) do
    begin
      Name := 'edSrvPassword';
      OnlyDigits := False;
      Width := 16;
      MaxLength := 24;
      Text := NetPassword;
    end;
    with AddEdit(_lc[I_NET_PORT]) do
    begin
      Name := 'edPort';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      Text := IntToStr(NetPort);
    end;
    with AddEdit(_lc[I_NET_MAX_CLIENTS]) do
    begin
      Name := 'edMaxPlayers';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 2;
      Text := IntToStr(NetMaxClients);
    end;
    with AddSwitch(_lc[I_NET_USE_MASTER]) do
    begin
      Name := 'swUseMaster';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if NetUseMaster then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    AddSpace();
    with AddLabel(_lc[I_MENU_MAP]) do
    begin
      Name := 'lbMap';
      FixedLength := 16;
      Text := gsMap;
      OnClick := @ProcSelectMapMenu;
    end;
    with AddSwitch(_lc[I_MENU_GAME_TYPE]) do
    begin
      Name := 'swGameMode';
      AddItem(_lc[I_MENU_GAME_TYPE_DM]);
      AddItem(_lc[I_MENU_GAME_TYPE_TDM]);
      AddItem(_lc[I_MENU_GAME_TYPE_CTF]);
      AddItem(_lc[I_MENU_GAME_TYPE_COOP]);
      case g_Game_TextToMode(gsGameMode) of
        GM_NONE,
        GM_DM:   ItemIndex := 0;
        GM_TDM:  ItemIndex := 1;
        GM_CTF:  ItemIndex := 2;
        GM_SINGLE,
        GM_COOP: ItemIndex := 3;
      end;
      OnChange := ProcSwitchMonstersCustom;
    end;
    with AddEdit(_lc[I_MENU_TIME_LIMIT]) do
    begin
      Name := 'edTimeLimit';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsTimeLimit > 0 then
        Text := IntToStr(gsTimeLimit);
    end;
    with AddEdit(_lc[I_MENU_GOAL_LIMIT]) do
    begin
      Name := 'edGoalLimit';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsGoalLimit > 0 then
        Text := IntToStr(gsGoalLimit);
    end;
    with AddEdit(_lc[I_MENU_MAX_LIVES]) do
    begin
      Name := 'edMaxLives';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsMaxLives > 0 then
        Text := IntToStr(gsMaxLives);
    end;
    with AddEdit(_lc[I_MENU_ITEM_RESPAWN_TIME]) do
    begin
      Name := 'edItemRespawnTime';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsItemRespawnTime > 0 then
        Text := IntToStr(gsItemRespawnTime);
    end;
    with AddSwitch(_lc[I_MENU_PLAYERS]) do
    begin
      Name := 'swPlayers';
      AddItem(_lc[I_MENU_COUNT_NONE]);
      AddItem(_lc[I_MENU_PLAYERS_ONE]);
      AddItem(_lc[I_MENU_PLAYERS_TWO]);
      ItemIndex := gsPlayers;
    end;
    with AddSwitch(_lc[I_MENU_TEAM_DAMAGE]) do
    begin
      Name := 'swTeamDamage';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_TEAMDAMAGE) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_TEAM_HIT]) do
    begin
      Name := 'swTeamHit';
      AddItem(_lc[I_MENU_TEAM_HIT_BOTH]);
      AddItem(_lc[I_MENU_TEAM_HIT_TRACE]);
      AddItem(_lc[I_MENU_TEAM_HIT_PROJECTILE]);
      AddItem(_lc[I_MENU_TEAM_HIT_NOTHING]);
      if (gsGameFlags and (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE)) = (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE) then
        ItemIndex := 0
      else if LongBool(gsGameFlags and GAME_OPTION_TEAMHITTRACE) then
        ItemIndex := 1
      else if LongBool(gsGameFlags and GAME_OPTION_TEAMHITPROJECTILE) then
        ItemIndex := 2
      else
        ItemIndex := 3;
    end;
    with AddSwitch(_lc[I_MENU_DEATHMATCH_KEYS]) do
    begin
      Name := 'swDeathmatchKeys';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_DMKEYS) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_ENABLE_EXITS]) do
    begin
      Name := 'swEnableExits';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_ALLOWEXIT) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_WEAPONS_STAY]) do
    begin
      Name := 'swWeaponStay';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_WEAPONSTAY) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_ENABLE_MONSTERS]) do
    begin
      Name := 'swMonsters';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_MONSTERS) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_BOTS_VS]) do
    begin
      Name := 'swBotsVS';
      AddItem(_lc[I_MENU_BOTS_VS_PLAYERS]);
      AddItem(_lc[I_MENU_BOTS_VS_MONSTERS]);
      AddItem(_lc[I_MENU_BOTS_VS_ALL]);
      ItemIndex := 2;
      if not LongBool(gsGameFlags and GAME_OPTION_BOTVSMONSTER) then
        ItemIndex := 0;
      if not LongBool(gsGameFlags and GAME_OPTION_BOTVSPLAYER) then
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_FLAG_DROP]) do
    begin
      Name := 'swFlagDrop';
      AddItem(_lc[I_MENU_FLAG_THROW]);
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if (gsGameFlags and (GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG)) = (GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG) then
        ItemIndex := 0
      else if LongBool(gsGameFlags and GAME_OPTION_ALLOWDROPFLAG) then
        ItemIndex := 1
      else
        ItemIndex := 2;
    end;
    AddSpace();
    AddButton(@ProcStartNetGame, _lc[I_MENU_START_GAME]);

    ReAlign();
  end;
  Menu.DefControl := 'mNetServerMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('NetClientMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_START_CLIENT]))) do
  begin
    Name := 'mNetClientMenu';

    AddButton(@ProcServerlist, _lc[I_NET_SLIST]);
    AddSpace();

    with AddEdit(_lc[I_NET_ADDRESS]) do
    begin
      Name := 'edIP';
      OnlyDigits :=False;
      Width := 12;
      MaxLength := 64;
      Text := 'localhost';
    end;
    with AddEdit(_lc[I_NET_PORT]) do
    begin
      Name := 'edPort';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      Text := '25666';
    end;
    with AddEdit(_lc[I_NET_SERVER_PASSWORD]) do
    begin
      Name := 'edPW';
      OnlyDigits := False;
      Width := 12;
      MaxLength := 32;
      Text := '';
    end;

    AddSpace();
    AddButton(@ProcConnectNetGame, _lc[I_MENU_CLIENT_CONNECT]);

    ReAlign();
  end;
  Menu.DefControl := 'mNetClientMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('LoadMenu');
  Menu.OnShow := ProcLoadMenu;
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_LOAD_GAME]))) do
  begin
    Name := 'mmLoadMenu';

    for a := 1 to 8 do
      with AddEdit('') do
      begin
        Name := 'edSlot'+IntToStr(a);
        Width := 16;
        MaxLength := 16;
        OnEnter := ProcLoadGame;
      end;
  end;
  Menu.DefControl := 'mmLoadMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('SaveMenu');
  Menu.OnShow := ProcSaveMenu;
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_SAVE_GAME]))) do
  begin
    Name := 'mmSaveMenu';

    for a := 1 to 8 do
      with AddEdit('') do
      begin
        Name := 'edSlot'+IntToStr(a);
        Width := 16;
        MaxLength := 16;
        OnChange := ProcSaveGame;
      end;
  end;
  Menu.DefControl := 'mmSaveMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('CustomGameMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_CUSTOM_GAME]))) do
  begin
    Name := 'mCustomGameMenu';
    with AddLabel(_lc[I_MENU_MAP]) do
    begin
      Name := 'lbMap';
      FixedLength := 16;
      Text := gsMap;
      OnClick := @ProcSelectMapMenu;
    end;
    with AddSwitch(_lc[I_MENU_GAME_TYPE]) do
    begin
      Name := 'swGameMode';
      AddItem(_lc[I_MENU_GAME_TYPE_DM]);
      AddItem(_lc[I_MENU_GAME_TYPE_TDM]);
      AddItem(_lc[I_MENU_GAME_TYPE_CTF]);
      AddItem(_lc[I_MENU_GAME_TYPE_COOP]);
      case g_Game_TextToMode(gsGameMode) of
        GM_NONE,
        GM_DM:   ItemIndex := 0;
        GM_TDM:  ItemIndex := 1;
        GM_CTF:  ItemIndex := 2;
        GM_SINGLE,
        GM_COOP: ItemIndex := 3;
      end;
      OnChange := ProcSwitchMonstersCustom;
    end;
    with AddEdit(_lc[I_MENU_TIME_LIMIT]) do
    begin
      Name := 'edTimeLimit';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsTimeLimit > 0 then
        Text := IntToStr(gsTimeLimit);
    end;
    with AddEdit(_lc[I_MENU_GOAL_LIMIT]) do
    begin
      Name := 'edGoalLimit';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsGoalLimit > 0 then
        Text := IntToStr(gsGoalLimit);
    end;
    with AddEdit(_lc[I_MENU_MAX_LIVES]) do
    begin
      Name := 'edMaxLives';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsMaxLives > 0 then
        Text := IntToStr(gsMaxLives);
    end;
    with AddEdit(_lc[I_MENU_ITEM_RESPAWN_TIME]) do
    begin
      Name := 'edItemRespawnTime';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
      if gsItemRespawnTime > 0 then
        Text := IntToStr(gsItemRespawnTime);
    end;
    with AddSwitch(_lc[I_MENU_PLAYERS]) do
    begin
      Name := 'swPlayers';
      AddItem(_lc[I_MENU_COUNT_NONE]);
      AddItem(_lc[I_MENU_PLAYERS_ONE]);
      AddItem(_lc[I_MENU_PLAYERS_TWO]);
      ItemIndex := gsPlayers;
    end;
    with AddSwitch(_lc[I_MENU_TEAM_DAMAGE]) do
    begin
      Name := 'swTeamDamage';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_TEAMDAMAGE) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_TEAM_HIT]) do
    begin
      Name := 'swTeamHit';
      AddItem(_lc[I_MENU_TEAM_HIT_BOTH]);
      AddItem(_lc[I_MENU_TEAM_HIT_TRACE]);
      AddItem(_lc[I_MENU_TEAM_HIT_PROJECTILE]);
      AddItem(_lc[I_MENU_TEAM_HIT_NOTHING]);
      if (gsGameFlags and (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE)) = (GAME_OPTION_TEAMHITTRACE or GAME_OPTION_TEAMHITPROJECTILE) then
        ItemIndex := 0
      else if LongBool(gsGameFlags and GAME_OPTION_TEAMHITTRACE) then
        ItemIndex := 1
      else if LongBool(gsGameFlags and GAME_OPTION_TEAMHITPROJECTILE) then
        ItemIndex := 2
      else
        ItemIndex := 3;
    end;
    with AddSwitch(_lc[I_MENU_DEATHMATCH_KEYS]) do
    begin
      Name := 'swDeathmatchKeys';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_DMKEYS) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_ENABLE_EXITS]) do
    begin
      Name := 'swEnableExits';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_ALLOWEXIT) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_WEAPONS_STAY]) do
    begin
      Name := 'swWeaponStay';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_WEAPONSTAY) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_ENABLE_MONSTERS]) do
    begin
      Name := 'swMonsters';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if LongBool(gsGameFlags and GAME_OPTION_MONSTERS) then
        ItemIndex := 0
      else
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_BOTS_VS]) do
    begin
      Name := 'swBotsVS';
      AddItem(_lc[I_MENU_BOTS_VS_PLAYERS]);
      AddItem(_lc[I_MENU_BOTS_VS_MONSTERS]);
      AddItem(_lc[I_MENU_BOTS_VS_ALL]);
      ItemIndex := 2;
      if not LongBool(gsGameFlags and GAME_OPTION_BOTVSMONSTER) then
        ItemIndex := 0;
      if not LongBool(gsGameFlags and GAME_OPTION_BOTVSPLAYER) then
        ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_FLAG_DROP]) do
    begin
      Name := 'swFlagDrop';
      AddItem(_lc[I_MENU_FLAG_THROW]);
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      if (gsGameFlags and (GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG)) = (GAME_OPTION_ALLOWDROPFLAG or GAME_OPTION_THROWFLAG) then
        ItemIndex := 0
      else if LongBool(gsGameFlags and GAME_OPTION_ALLOWDROPFLAG) then
        ItemIndex := 1
      else
        ItemIndex := 2;
    end;
    AddSpace();
    AddButton(@ProcStartCustomGame, _lc[I_MENU_START_GAME]);

    ReAlign();
  end;
  Menu.DefControl := 'mCustomGameMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('CampaignMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_CAMPAIGN]))) do
  begin
    Name := 'mCampaignMenu';

    AddSpace();
    AddSpace();
    AddSpace();
    AddSpace();
    AddSpace();
    AddSpace();

    with AddFileList('', 15, 4) do
    begin
      Name := 'lsWAD';
      OnChange := ProcSelectCampaignWAD;

      Sort := True;
      Dirs := True;
      FileMask := '*.wad|*.pk3|*.zip|*.dfz';
      SetBase(MegawadDirs);
    end;

    with AddLabel(_lc[I_MENU_MAP_NAME]) do
    begin
      Name := 'lbWADName';
      FixedLength := 8;
      Enabled := False;
    end;
    with AddLabel(_lc[I_MENU_MAP_AUTHOR]) do
    begin
      Name := 'lbWADAuthor';
      FixedLength := 8;
      Enabled := False;
    end;
    AddLine(_lc[I_MENU_MAP_DESCRIPTION]);
    with AddMemo('', 15, 3) do
    begin
      Name := 'meWADDescription';
      Color := MENU_ITEMSCTRL_COLOR;
    end;
    with AddSwitch(_lc[I_MENU_PLAYERS]) do
    begin
      Name := 'swPlayers';
      AddItem(_lc[I_MENU_PLAYERS_ONE]);
      AddItem(_lc[I_MENU_PLAYERS_TWO]);
    end;
    AddSpace();
    AddButton(@ProcStartCampaign, _lc[I_MENU_START_GAME]);

    ReAlign();

    with TGUIImage(Menu.AddChild(TGUIImage.Create)) do
    begin
      Name := 'mpWADImage';
      DefaultRes := 'NOPIC';
      X := GetControl('lsWAD').X+4;
      Y := GetControl('lsWAD').Y-128-MENU_VSPACE;
    end;
  end;
  Menu.DefControl := 'mCampaignMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('SelectMapMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_SELECT_MAP]))) do
  begin
    Name := 'mSelectMapMenu';
    with AddFileList(_lc[I_MENU_MAP_WAD], 12, 4) do
    begin
      Name := 'lsMapWAD';
      OnChange := ProcSelectWAD;

      Sort := True;
      Dirs := True;
      FileMask := '*.wad|*.pk3|*.zip|*.dfz';
      SetBase(MapDirs);
    end;
    with AddList(_lc[I_MENU_MAP_RESOURCE], 12, 4) do
    begin
      Name := 'lsMapRes';
      Sort := True;
      OnChange := ProcSelectMap;
    end;
    AddSpace();
    with AddLabel(_lc[I_MENU_MAP_NAME]) do
    begin
      Name := 'lbMapName';
      FixedLength := 24;
      Enabled := False;
    end;
    with AddLabel(_lc[I_MENU_MAP_AUTHOR]) do
    begin
      Name := 'lbMapAuthor';
      FixedLength := 16;
      Enabled := False;
    end;
    with AddLabel(_lc[I_MENU_MAP_SIZE]) do
    begin
      Name := 'lbMapSize';
      FixedLength := 10;
      Enabled := False;
    end;
    with AddMemo(_lc[I_MENU_MAP_DESCRIPTION], 12, 4) do
    begin
      Name := 'meMapDescription';
    end;

    ReAlign();

    with TGUIMapPreview(Menu.AddChild(TGUIMapPreview.Create)) do
    begin
      Name := 'mpMapPreview';
      X := GetControl('lsMapWAD').X+TGUIListBox(GetControl('lsMapWAD')).GetWidth()+2;
      Y := GetControl('lsMapWAD').Y;
    end;
    with TGUILabel(Menu.AddChild(TGUILabel.Create('', gMenuSmallFont))) do
    begin
      Name := 'lbMapScale';
      FixedLength := 8;
      Enabled := False;
      Color := MENU_ITEMSCTRL_COLOR;
      X := GetControl('lsMapWAD').X +
        TGUIListBox(GetControl('lsMapWAD')).GetWidth() +
        2 + MAPPREVIEW_WIDTH*4;
      Y := GetControl('lsMapWAD').Y + MAPPREVIEW_HEIGHT*16 + 16;
    end;
  end;
  Menu.OnClose := ProcSetMap;
  Menu.DefControl := 'mSelectMapMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_OPTIONS]))) do
  begin
    Name := 'mmOptionsMenu';
    AddButton(nil, _lc[I_MENU_VIDEO_OPTIONS], 'OptionsVideoMenu');
    AddButton(nil, _lc[I_MENU_SOUND_OPTIONS], 'OptionsSoundMenu');
    AddButton(nil, _lc[I_MENU_GAME_OPTIONS], 'OptionsGameMenu');
    AddButton(nil, _lc[I_MENU_CONTROLS_OPTIONS], 'OptionsControlsMenu');
    AddButton(nil, _lc[I_MENU_PLAYER_OPTIONS], 'OptionsPlayersMenu');
    AddButton(nil, _lc[I_MENU_LANGUAGE_OPTIONS], 'OptionsLanguageMenu');
    AddSpace();
    AddButton(nil, _lc[I_MENU_SAVED_OPTIONS], 'SavedOptionsMenu').Color := _RGB(255, 0, 0);
    AddButton(nil, _lc[I_MENU_DEFAULT_OPTIONS], 'DefaultOptionsMenu').Color := _RGB(255, 0, 0);
  end;
  Menu.OnClose := ProcApplyOptions;
  Menu.DefControl := 'mmOptionsMenu';
  g_GUI_AddWindow(Menu);

  Menu := CreateYNMenu('SavedOptionsMenu', _lc[I_MENU_LOAD_SAVED_PROMT], Round(gScreenWidth*0.6),
                       gMenuSmallFont, @ProcSavedMenuKeyDown);
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsVideoMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_VIDEO_OPTIONS]))) do
  begin
    Name := 'mOptionsVideoMenu';
    AddButton(@ProcVideoOptionsRes, _lc[I_MENU_VIDEO_RESOLUTION], 'OptionsVideoResMenu');
    with AddSwitch(_lc[I_MENU_VIDEO_BPP]) do
    begin
      Name := 'swBPP';
      AddItem('16');
      AddItem('32');
    end;
    with AddSwitch(_lc[I_MENU_VIDEO_VSYNC]) do
    begin
      Name := 'swVSync';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_VIDEO_FILTER_SKY]) do
    begin
      Name := 'swTextureFilter';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_VIDEO_INTERPOLATION]) do
    begin
      Name := 'swInterp';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_VIDEO_LEGACY_COMPATIBLE]) do
    begin
      Name := 'swLegacyNPOT';
      AddItem(_lc[I_MENU_NO]);
      AddItem(_lc[I_MENU_YES]);
    end;
    AddSpace();
    AddText(_lc[I_MENU_VIDEO_NEED_RESTART], Round(gScreenWidth*0.6));
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsVideoMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsVideoResMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_RESOLUTION_SELECT]))) do
  begin
    Name := 'mOptionsVideoResMenu';
    with AddLabel(_lc[I_MENU_RESOLUTION_CURRENT]) do
    begin
      Name := 'lbCurrentRes';
      FixedLength := 24;
      Enabled := False;
    end;
    with AddList(_lc[I_MENU_RESOLUTION_LIST], 12, 6) do
    begin
      Name := 'lsResolution';
      Sort := False;
    end;
    with AddSwitch(_lc[I_MENU_RESOLUTION_FULLSCREEN]) do
    begin
      Name := 'swFullScreen';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_SCALE_FACTOR]) do
    begin
      Name := 'swResFactor';
      AddItem('1x');
      for i := 2 to gRC_Width div 640 do
        AddItem(IntToStr(i) + 'x');
    end;
    AddSpace();
    AddButton(@ProcApplyVideoOptions, _lc[I_MENU_RESOLUTION_APPLY]);
    UpdateIndex();
  end;
  Menu.DefControl := 'mOptionsVideoResMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsSoundMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_SOUND_OPTIONS]))) do
  begin
    Name := 'mOptionsSoundMenu';
    with AddScroll(_lc[I_MENU_SOUND_MUSIC_LEVEL]) do
    begin
      Name := 'scMusicLevel';
      Max := 16;
      OnChange := ProcChangeSoundSettings;
    end;
    with AddScroll(_lc[I_MENU_SOUND_SOUND_LEVEL]) do
    begin
      Name := 'scSoundLevel';
      Max := 16;
      OnChange := ProcChangeSoundSettings;
    end;
    with AddScroll(_lc[I_MENU_SOUND_MAX_SIM_SOUNDS]) do
    begin
      Name := 'scMaxSimSounds';
      Max := 16;
    end;
    with AddSwitch (_lc[I_MENU_SOUND_ANNOUNCE]) do
    begin;
      Name := 'swAnnouncer';
      AddItem(_lc[I_MENU_ANNOUNCE_NONE]);
      AddItem(_lc[I_MENU_ANNOUNCE_ME]);
      AddItem(_lc[I_MENU_ANNOUNCE_MEPLUS]);
      AddItem(_lc[I_MENU_ANNOUNCE_ALL]);
    end;
    // ������������� �������� �������� (DF / Doom 2)
    with AddSwitch (_lc[I_MENU_SOUND_COMPAT]) do
    begin;
      Name := 'swSoundEffects';
      AddItem(_lc[I_MENU_COMPAT_DOOM2]);
      AddItem(_lc[I_MENU_COMPAT_DF]);
    end;
    // ������������� ������ ����
    with AddSwitch (_lc[I_MENU_SOUND_CHAT]) do
    begin;
      Name := 'swChatSpeech';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_SOUND_INACTIVE_SOUNDS]) do
    begin
      Name := 'swInactiveSounds';
      AddItem(_lc[I_MENU_SOUND_INACTIVE_SOUNDS_ON]);
      AddItem(_lc[I_MENU_SOUND_INACTIVE_SOUNDS_OFF]);
    end;
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsSoundMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsGameMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_GAME_OPTIONS]))) do
  begin
    Name := 'mOptionsGameMenu';
    with AddScroll(_lc[I_MENU_GAME_PARTICLES_COUNT]) do
    begin
      Name := 'scParticlesCount';
      Max := 20;
    end;
    with AddSwitch(_lc[I_MENU_GAME_BLOOD_COUNT]) do
    begin
      Name := 'swBloodCount';
      AddItem(_lc[I_MENU_COUNT_NONE]);
      AddItem(_lc[I_MENU_COUNT_SMALL]);
      AddItem(_lc[I_MENU_COUNT_NORMAL]);
      AddItem(_lc[I_MENU_COUNT_BIG]);
      AddItem(_lc[I_MENU_COUNT_VERYBIG]);
    end;
    with AddScroll(_lc[I_MENU_GAME_MAX_SHELLS]) do
    begin
      Name := 'scShellsMax';
      Max := 20;
    end;
    with AddScroll(_lc[I_MENU_GAME_GIBS_COUNT]) do
    begin
      Name := 'scGibsMax';
      Max := 20;
    end;
    with AddScroll(_lc[I_MENU_GAME_MAX_CORPSES]) do
    begin
      Name := 'scCorpsesMax';
      Max := 20;
    end;
    with AddSwitch(_lc[I_MENU_GAME_MAX_GIBS]) do
    begin
      Name := 'swGibsCount';
      AddItem(_lc[I_MENU_COUNT_NONE]);
      AddItem(_lc[I_MENU_COUNT_SMALL]);
      AddItem(_lc[I_MENU_COUNT_NORMAL]);
      AddItem(_lc[I_MENU_COUNT_BIG]);
      AddItem(_lc[I_MENU_COUNT_VERYBIG]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_CORPSE_TYPE]) do
    begin
      Name := 'swCorpseType';
      AddItem(_lc[I_MENU_GAME_CORPSE_TYPE_SIMPLE]);
      AddItem(_lc[I_MENU_GAME_CORPSE_TYPE_ADV]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_GIBS_TYPE]) do
    begin
      Name := 'swGibsType';
      AddItem(_lc[I_MENU_GAME_GIBS_TYPE_SIMPLE]);
      AddItem(_lc[I_MENU_GAME_GIBS_TYPE_ADV]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_BLOOD_TYPE]) do
    begin
      Name := 'swBloodType';
      AddItem(_lc[I_MENU_GAME_BLOOD_TYPE_SIMPLE]);
      AddItem(_lc[I_MENU_GAME_BLOOD_TYPE_ADV]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_SCREEN_FLASH]) do
    begin
      Name := 'swScreenFlash';
      AddItem(_lc[I_MENU_NO]);
      AddItem(_lc[I_MENU_COMPAT_DF]);
      AddItem(_lc[I_MENU_COMPAT_DOOM2]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_BACKGROUND]) do
    begin
      Name := 'swBackground';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_MESSAGES]) do
    begin
      Name := 'swMessages';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_REVERT_PLAYERS]) do
    begin
      Name := 'swRevertPlayers';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_CHAT_BUBBLE]) do
    begin
      Name := 'swChatBubble';
      AddItem(_lc[I_MENU_GAME_CHAT_TYPE_NONE]);
      AddItem(_lc[I_MENU_GAME_CHAT_TYPE_SIMPLE]);
      AddItem(_lc[I_MENU_GAME_CHAT_TYPE_ADV]);
      AddItem(_lc[I_MENU_GAME_CHAT_TYPE_COLOR]);
      AddItem(_lc[I_MENU_GAME_CHAT_TYPE_TEXTURE]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_PLAYER_INDICATOR]) do
    begin
      Name := 'swPlayerIndicator';
      AddItem(_lc[I_MENU_GAME_INDICATOR_NONE]);
      AddItem(_lc[I_MENU_GAME_INDICATOR_OWN]);
      AddItem(_lc[I_MENU_GAME_INDICATOR_ALL]);
    end;
    with AddSwitch(_lc[I_MENU_GAME_INDICATOR_STYLE]) do
    begin
      Name := 'swPlayerIndicatorStyle';
      AddItem(_lc[I_MENU_GAME_INDICATOR_ARROW]);
      AddItem(_lc[I_MENU_GAME_INDICATOR_NAME]);
    end;
    with AddScroll(_lc[I_MENU_GAME_SCALE_FACTOR]) do
    begin
      Name := 'scScaleFactor';
      Max := 10;
      OnChange := ProcChangeGameSettings;
    end;
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsGameMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_CONTROLS_OPTIONS]))) do
  begin
    Name := 'mOptionsControlsMenu';
    AddLine(_lc[I_MENU_CONTROL_GLOBAL]);
    AddKeyRead(_lc[I_MENU_CONTROL_SCREENSHOT]).Name := _lc[I_MENU_CONTROL_SCREENSHOT];
    AddKeyRead(_lc[I_MENU_CONTROL_STAT]).Name := _lc[I_MENU_CONTROL_STAT];
    AddKeyRead(_lc[I_MENU_CONTROL_CHAT]).Name := _lc[I_MENU_CONTROL_CHAT];
    AddKeyRead(_lc[I_MENU_CONTROL_TEAMCHAT]).Name := _lc[I_MENU_CONTROL_TEAMCHAT];
    AddSpace();
    AddButton(nil, _lc[I_MENU_PLAYER_1_KBD], 'OptionsControlsP1Menu');
    {AddButton(nil, _lc[I_MENU_PLAYER_1_ALT], 'OptionsControlsP1MenuAlt');}
    AddButton(nil, _lc[I_MENU_PLAYER_1_WEAPONS], 'OptionsControlsP1MenuWeapons');
    AddButton(nil, _lc[I_MENU_PLAYER_2_KBD], 'OptionsControlsP2Menu');
    {AddButton(nil, _lc[I_MENU_PLAYER_2_ALT], 'OptionsControlsP2MenuAlt');}
    AddButton(nil, _lc[I_MENU_PLAYER_2_WEAPONS], 'OptionsControlsP2MenuWeapons');
    if e_HasJoysticks then
    begin
      AddSpace();
      AddButton(nil, _lc[I_MENU_CONTROL_JOYSTICKS], 'OptionsControlsJoystickMenu');
    end;
    if g_touch_enabled then
    begin
      AddSpace();
      AddButton(nil, _lc[I_MENU_CONTROL_TOUCH], 'OptionsControlsTouchMenu');
    end;
  end;
  Menu.DefControl := 'mOptionsControlsMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsP1Menu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_PLAYER_1_KBD]))) do
  begin
    Name := 'mOptionsControlsP1Menu';
    AddKeyRead2(_lc[I_MENU_CONTROL_LEFT]).Name := _lc[I_MENU_CONTROL_LEFT];
    AddKeyRead2(_lc[I_MENU_CONTROL_RIGHT]).Name := _lc[I_MENU_CONTROL_RIGHT];
    AddKeyRead2(_lc[I_MENU_CONTROL_UP]).Name := _lc[I_MENU_CONTROL_UP];
    AddKeyRead2(_lc[I_MENU_CONTROL_DOWN]).Name := _lc[I_MENU_CONTROL_DOWN];
    AddKeyRead2(_lc[I_MENU_CONTROL_JUMP]).Name := _lc[I_MENU_CONTROL_JUMP];
    AddKeyRead2(_lc[I_MENU_CONTROL_FIRE]).Name := _lc[I_MENU_CONTROL_FIRE];
    AddKeyRead2(_lc[I_MENU_CONTROL_USE]).Name := _lc[I_MENU_CONTROL_USE];
    AddKeyRead2(_lc[I_MENU_CONTROL_NEXT_WEAPON]).Name := _lc[I_MENU_CONTROL_NEXT_WEAPON];
    AddKeyRead2(_lc[I_MENU_CONTROL_PREV_WEAPON]).Name := _lc[I_MENU_CONTROL_PREV_WEAPON];
    AddKeyRead2(_lc[I_MENU_CONTROL_STRAFE]).Name := _lc[I_MENU_CONTROL_STRAFE];
    AddKeyRead2(_lc[I_MENU_CONTROL_DROPFLAG]).Name := _lc[I_MENU_CONTROL_DROPFLAG];
  end;
  Menu.DefControl := 'mOptionsControlsP1Menu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsP1MenuWeapons');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_PLAYER_1_WEAPONS]))) do
  begin
    Name := 'mOptionsControlsP1MenuWeapons';
    for i := WP_FIRST to WP_LAST do
      AddKeyRead2(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)]).Name :=
        _lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)];
  end;
  Menu.DefControl := 'mOptionsControlsP1MenuWeapons';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsP2Menu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_PLAYER_2_KBD]))) do
  begin
    Name := 'mOptionsControlsP2Menu';
    AddKeyRead2(_lc[I_MENU_CONTROL_LEFT]).Name := _lc[I_MENU_CONTROL_LEFT];
    AddKeyRead2(_lc[I_MENU_CONTROL_RIGHT]).Name := _lc[I_MENU_CONTROL_RIGHT];
    AddKeyRead2(_lc[I_MENU_CONTROL_UP]).Name := _lc[I_MENU_CONTROL_UP];
    AddKeyRead2(_lc[I_MENU_CONTROL_DOWN]).Name := _lc[I_MENU_CONTROL_DOWN];
    AddKeyRead2(_lc[I_MENU_CONTROL_JUMP]).Name := _lc[I_MENU_CONTROL_JUMP];
    AddKeyRead2(_lc[I_MENU_CONTROL_FIRE]).Name := _lc[I_MENU_CONTROL_FIRE];
    AddKeyRead2(_lc[I_MENU_CONTROL_USE]).Name := _lc[I_MENU_CONTROL_USE];
    AddKeyRead2(_lc[I_MENU_CONTROL_NEXT_WEAPON]).Name := _lc[I_MENU_CONTROL_NEXT_WEAPON];
    AddKeyRead2(_lc[I_MENU_CONTROL_PREV_WEAPON]).Name := _lc[I_MENU_CONTROL_PREV_WEAPON];
    AddKeyRead2(_lc[I_MENU_CONTROL_STRAFE]).Name := _lc[I_MENU_CONTROL_STRAFE];
    AddKeyRead2(_lc[I_MENU_CONTROL_DROPFLAG]).Name := _lc[I_MENU_CONTROL_DROPFLAG];
  end;
  Menu.DefControl := 'mOptionsControlsP2Menu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsP2MenuWeapons');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_PLAYER_2_WEAPONS]))) do
  begin
    Name := 'mOptionsControlsP2MenuWeapons';
    for i := WP_FIRST to WP_LAST do
      AddKeyRead2(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)]).Name :=
        _lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)];
  end;
  Menu.DefControl := 'mOptionsControlsP2MenuWeapons';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsJoystickMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_CONTROL_JOYSTICKS]))) do
  begin
    Name := 'mOptionsControlsJoystickMenu';
    for i := 0 to e_MaxJoys - 1 do
      with AddScroll(Format(_lc[I_MENU_CONTROL_DEADZONE], [i + 1])) do
      begin
        Name := 'scDeadzone' + IntToStr(i);
        Max := 20
      end
  end;
  Menu.DefControl := 'mOptionsControlsJoystickMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsControlsTouchMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_CONTROL_TOUCH]))) do
  begin
    Name := 'mOptionsControlsTouchMenu';
    with AddSwitch(_lc[I_MENU_CONTROL_TOUCH_ALT]) do
    begin
      Name := 'swTouchAlt';
      AddItem(_lc[I_MENU_NO]);
      AddItem(_lc[I_MENU_YES]);
      OnChange := ProcChangeTouchSettings;
    end;
    with AddScroll(_lc[I_MENU_CONTROL_TOUCH_SIZE]) do
    begin
      Name := 'scTouchSize';
      Max := 20;
      OnChange := ProcChangeTouchSettings;
    end;
    with AddSwitch(_lc[I_MENU_CONTROL_TOUCH_FIRE]) do
    begin
      Name := 'swTouchFire';
      AddItem(_lc[I_MENU_NO]);
      AddItem(_lc[I_MENU_YES]);
    end;
    with AddScroll(_lc[I_MENU_CONTROL_TOUCH_OFFSET]) do
    begin
      Name := 'scTouchOffset';
      Max := 20;
      OnChange := ProcChangeTouchSettings;
    end;
  end;
  Menu.DefControl := 'mOptionsControlsTouchMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsPlayersMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_PLAYER_OPTIONS]))) do
  begin
    Name := 'mOptionsPlayersMenu';
    AddButton(nil, _lc[I_MENU_PLAYER_1], 'OptionsPlayersP1Menu');
    AddButton(nil, _lc[I_MENU_PLAYER_2], 'OptionsPlayersP2Menu');
  end;
  Menu.DefControl := 'mOptionsPlayersMenu';
  g_GUI_AddWindow(Menu);

  CreatePlayerOptionsMenu('P1');
  CreatePlayerOptionsMenu('P2');

  Menu := TGUIWindow.Create('OptionsPlayersMIMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_MODEL_INFO]))) do
  begin
    Name := 'mOptionsPlayersMIMenu';
    with AddLabel(_lc[I_MENU_MODEL_NAME]) do
    begin
      Name := 'lbName';
      FixedLength := 16;
    end;
    with AddLabel(_lc[I_MENU_MODEL_AUTHOR]) do
    begin
      Name := 'lbAuthor';
      FixedLength := 16;
    end;
    with AddMemo(_lc[I_MENU_MODEL_COMMENT], 14, 6) do
    begin
      Name := 'meComment';
    end;
    AddSpace();
    AddLine(_lc[I_MENU_MODEL_OPTIONS]);
    with AddLabel(_lc[I_MENU_MODEL_WEAPON]) do
    begin
      Name := 'lbWeapon';
      FixedLength := Max(Length(_lc[I_MENU_YES]), Length(_lc[I_MENU_NO]));
    end;
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsPlayersMIMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsPlayersP1WeaponMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_WEAPON]))) do
  begin
    Name := 'mOptionsPlayersP1WeaponMenu';
    with AddSwitch(_lc[I_MENU_WEAPON_SWITCH]) do
    begin
      Name := 'swWeaponAutoswitch';
      AddItem(_lc[I_MENU_NO]);
      AddItem(_lc[I_MENU_WEAPON_SWITCH_LINEAR]);
      AddItem(_lc[I_MENU_WEAPON_SWITCH_PREFERENCE]);
    end;
    with AddSwitch(_lc[I_MENU_WEAPON_ALLOW_EMPTY]) do
    begin
      Name := 'swWeaponAllowEmpty';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_KASTET_ALLOW]) do
    begin
      Name := 'swWeaponAllowFist';
      AddItem(_lc[I_MENU_KASTET_ALLOW_ALWAYS]);
      AddItem(_lc[I_MENU_KASTET_ALLOW_BERSERK]);
    end;
    AddButton(@ProcOptionsPlayerP1WeaponPreferencesMenu, _lc[I_MENU_WEAPON_SWITCH_PRIORITY]);
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsPlayersP1WeaponMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsPreferencesP1WeaponMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_WEAPON_PRIORITY_PLAYER_1]))) do
  begin
    Name := 'mOptionsPreferencesP1WeaponMenu';
    for i := WP_FIRST to WP_LAST do
    begin
        with AddSwitch(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)]) do
        begin
          Name := IntToStr(i);
          for a := WP_FIRST to WP_LAST+1 do
            begin
              AddItem(IntToStr(a));            
            end;
          ItemIndex := i
        end;
    end;
    with AddSwitch(_lc[I_GAME_WEAPON_BERSERK]) do
    begin
      Name := IntToStr(WP_LAST+1);
      for a := WP_FIRST to WP_LAST+1 do
      begin
         AddItem(IntToStr(a));            
      end;
      ItemIndex := WP_LAST + 1;
    end;
  end;    
  Menu.DefControl := 'mOptionsPreferencesP1WeaponMenu';
  g_GUI_AddWindow(Menu);


  Menu := TGUIWindow.Create('OptionsPlayersP2WeaponMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_WEAPON]))) do
  begin
    Name := 'mOptionsPlayersP2WeaponMenu';
    with AddSwitch(_lc[I_MENU_WEAPON_SWITCH]) do
    begin
      Name := 'swWeaponAutoswitch';
      AddItem(_lc[I_MENU_NO]);
      AddItem(_lc[I_MENU_WEAPON_SWITCH_LINEAR]);
      AddItem(_lc[I_MENU_WEAPON_SWITCH_PREFERENCE]);
    end;
    with AddSwitch(_lc[I_MENU_WEAPON_ALLOW_EMPTY]) do
    begin
      Name := 'swWeaponAllowEmpty';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
    end;
    with AddSwitch(_lc[I_MENU_KASTET_ALLOW]) do
    begin
      Name := 'swWeaponAllowFist';
      AddItem(_lc[I_MENU_KASTET_ALLOW_ALWAYS]);
      AddItem(_lc[I_MENU_KASTET_ALLOW_BERSERK]);
    end;
    AddButton(@ProcOptionsPlayerP2WeaponPreferencesMenu, _lc[I_MENU_WEAPON_SWITCH_PRIORITY]);
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsPlayersP2WeaponMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('OptionsPreferencesP2WeaponMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_WEAPON_PRIORITY_PLAYER_2]))) do
  begin
    Name := 'mOptionsPreferencesP2WeaponMenu';
    for i := WP_FIRST to WP_LAST do
    begin
        with AddSwitch(_lc[TStrings_Locale(Cardinal(I_GAME_WEAPON0) + i)]) do
        begin
          Name := IntToStr(i);
          for a := WP_FIRST to WP_LAST+1 do
            begin
              AddItem(IntToStr(a));            
            end;
          ItemIndex := i
        end;
    end;
    with AddSwitch(_lc[I_GAME_WEAPON_BERSERK]) do
    begin
      Name := IntToStr(WP_LAST+1);
      for a := WP_FIRST to WP_LAST+1 do
      begin
         AddItem(IntToStr(a));            
      end;
      ItemIndex := WP_LAST + 1;
    end;
  end;
  Menu.DefControl := 'mOptionsPreferencesP2WeaponMenu';
  g_GUI_AddWindow(Menu);  

  Menu := TGUIWindow.Create('OptionsLanguageMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_LANGUAGE_OPTIONS]))) do
  begin
    Name := 'mOptionsLanguageMenu';
    AddButton(@ProcSetRussianLanguage, _lc[I_MENU_LANGUAGE_RUSSIAN]);
    AddButton(@ProcSetEnglishLanguage, _lc[I_MENU_LANGUAGE_ENGLISH]);
    ReAlign();
  end;
  Menu.DefControl := 'mOptionsLanguageMenu';
  g_GUI_AddWindow(Menu);

  Menu := CreateYNMenu('DefaultOptionsMenu', _lc[I_MENU_SET_DEFAULT_PROMT], Round(gScreenWidth*0.6),
                       gMenuSmallFont, @ProcDefaultMenuKeyDown);
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('AuthorsMenu');
  Menu.BackTexture := 'INTER';
  Menu.OnClose := ProcAuthorsClose;

// ���������:
  _y := 16;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_CAP_1], gMenuFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := (gScreenWidth div 2)-(GetWidth() div 2);
    Y := _y;
    _y := _y+GetHeight();
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(Format(_lc[I_CREDITS_CAP_2], [GAME_VERSION, NET_PROTOCOL_VER]), gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := (gScreenWidth div 2)-(GetWidth() div 2);
    Y := _y;
    _y := _y+GetHeight()+32;
  end;
// ��� �����: ��� �����
  cx := gScreenWidth div 2 - 320 + 64;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_1], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := cx;
    Y := _y;
    _y := _y+22;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_1_1], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := _y+36;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_2], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := cx;
    Y := _y;
    _y := _y+22;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_2_1], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := _y+22;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_2_2], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := _y+36;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_3], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := cx;
    Y := _y;
    _y := _y+22;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_3_1], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X :=  cx+32;
    Y := _y;
   _y := _y+36;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_4], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := cx;
    Y := _y;
    _y := _y+22;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_A_4_1], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := gScreenHeight - 128;
  end;
// ����������:
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_CAP_3], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := cx;
    Y := _y;
    _y := _y+16;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_CLO_1], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := _y+GetHeight();
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_CLO_2], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := _y+GetHeight();
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_CLO_3], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 255, 255);
    X := cx+32;
    Y := _y;
    _y := gScreenHeight - 32;
  end;
  with TGUILabel(Menu.AddChild(TGUILabel.Create(_lc[I_CREDITS_CLO_4], gMenuSmallFont))) do
  begin
    Color := _RGB(255, 0, 0);
    X := gScreenWidth div 2 - GetWidth() div 2;
    Y := _y;
  end;
  g_GUI_AddWindow(Menu);

  Menu := CreateYNMenu('ExitMenu', _lc[I_MENU_EXIT_PROMT], Round(gScreenWidth*0.6),
                       gMenuSmallFont, @ProcExitMenuKeyDown);
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('GameSingleMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_MAIN_MENU]))) do
  begin
    Name := 'mmGameSingleMenu';
    AddButton(nil, _lc[I_MENU_LOAD_GAME], 'LoadMenu');
    AddButton(nil, _lc[I_MENU_SAVE_GAME], 'SaveMenu').Name := 'save';
    AddButton(@ReadGameSettings, _lc[I_MENU_SET_GAME], 'GameSetGameMenu');
    AddButton(@ReadOptions, _lc[I_MENU_OPTIONS], 'OptionsMenu');
    AddButton(nil, _lc[I_MENU_RESTART], 'RestartGameMenu');
    AddButton(nil, _lc[I_MENU_END_GAME], 'EndGameMenu');
  end;
  Menu.DefControl := 'mmGameSingleMenu';
  Menu.MainWindow := True;
  Menu.OnClose := ProcGMClose;
  Menu.OnShow := ProcGMShow;
  g_GUI_AddWindow(Menu);

  Menu := CreateYNMenu('EndGameMenu', _lc[I_MENU_END_GAME_PROMT], Round(gScreenWidth*0.6),
                       gMenuSmallFont, @ProcEndMenuKeyDown);
  g_GUI_AddWindow(Menu);

  Menu := CreateYNMenu('RestartGameMenu', _lc[I_MENU_RESTART_GAME_PROMT], Round(gScreenWidth*0.6),
                       gMenuSmallFont, @ProcRestartMenuKeyDown);
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('GameCustomMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_MAIN_MENU]))) do
  begin
    Name := 'mmGameCustomMenu';
    AddButton(nil, _lc[I_MENU_CHANGE_PLAYERS], 'TeamMenu');
    AddButton(nil, _lc[I_MENU_LOAD_GAME], 'LoadMenu');
    AddButton(nil, _lc[I_MENU_SAVE_GAME], 'SaveMenu').Name := 'save';
    AddButton(@ReadGameSettings, _lc[I_MENU_SET_GAME], 'GameSetGameMenu');
    AddButton(@ReadOptions, _lc[I_MENU_OPTIONS], 'OptionsMenu');
    AddButton(nil, _lc[I_MENU_RESTART], 'RestartGameMenu');
    AddButton(nil, _lc[I_MENU_END_GAME], 'EndGameMenu');
  end;
  Menu.DefControl := 'mmGameCustomMenu';
  Menu.MainWindow := True;
  Menu.OnClose := ProcGMClose;
  Menu.OnShow := ProcGMShow;
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('GameServerMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_MAIN_MENU]))) do
  begin
    Name := 'mmGameServerMenu';
    AddButton(nil, _lc[I_MENU_CHANGE_PLAYERS], 'TeamMenu');
    AddButton(@ReadGameSettings, _lc[I_MENU_SET_GAME], 'GameSetGameMenu');
    AddButton(@ReadOptions, _lc[I_MENU_OPTIONS], 'OptionsMenu');
    AddButton(nil, _lc[I_MENU_RESTART], 'RestartGameMenu');
    AddButton(nil, _lc[I_MENU_END_GAME], 'EndGameMenu');
  end;
  Menu.DefControl := 'mmGameServerMenu';
  Menu.MainWindow := True;
  Menu.OnClose := ProcGMClose;
  Menu.OnShow := ProcGMShow;
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('GameClientMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_MAIN_MENU]))) do
  begin
    Name := 'mmGameClientMenu';
    AddButton(nil, _lc[I_MENU_CHANGE_PLAYERS], 'TeamMenu');
    AddButton(@ReadOptions, _lc[I_MENU_OPTIONS], 'OptionsMenu');
    AddButton(nil, _lc[I_MENU_END_GAME], 'EndGameMenu');
  end;
  Menu.DefControl := 'mmGameClientMenu';
  Menu.MainWindow := True;
  Menu.OnClose := ProcGMClose;
  Menu.OnShow := ProcGMShow;
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('ClientPasswordMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuSmallFont, gMenuSmallFont, _lc[I_MENU_ENTERPASSWORD]))) do
  begin
    Name := 'mClientPasswordMenu';
    with AddEdit(_lc[I_NET_SERVER_PASSWORD]) do
    begin
      Name := 'edPW';
      Width := 12;
      MaxLength := 32;
    end;
    AddSpace;

    AddButton(@ProcEnterPassword, _lc[I_MENU_START_GAME]);
    ReAlign();
  end;
  Menu.DefControl := 'mClientPasswordMenu';
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('GameSetGameMenu');
  with TGUIMenu(Menu.AddChild(TGUIMenu.Create(gMenuFont, gMenuSmallFont, _lc[I_MENU_SET_GAME]))) do
  begin
    Name := 'mGameSetGameMenu';
    with AddSwitch(_lc[I_MENU_TEAM_DAMAGE]) do
    begin
      Name := 'swTeamDamage';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      ItemIndex := 1;
    end;
    with AddSwitch(_lc[I_MENU_TEAM_HIT]) do
    begin
      Name := 'swTeamHit';
      AddItem(_lc[I_MENU_TEAM_HIT_BOTH]);
      AddItem(_lc[I_MENU_TEAM_HIT_TRACE]);
      AddItem(_lc[I_MENU_TEAM_HIT_PROJECTILE]);
      AddItem(_lc[I_MENU_TEAM_HIT_NOTHING]);
      ItemIndex := 0
    end;
    with AddSwitch(_lc[I_MENU_DEATHMATCH_KEYS]) do
    begin
      Name := 'swDeathmatchKeys';
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      ItemIndex := 1;
    end;
    with AddEdit(_lc[I_MENU_TIME_LIMIT]) do
    begin
      Name := 'edTimeLimit';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
    end;
    with AddEdit(_lc[I_MENU_GOAL_LIMIT]) do
    begin
      Name := 'edGoalLimit';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
    end;
    with AddEdit(_lc[I_MENU_MAX_LIVES]) do
    begin
      Name := 'edMaxLives';
      OnlyDigits := True;
      Width := 4;
      MaxLength := 5;
    end;
    with AddSwitch(_lc[I_MENU_BOTS_VS]) do
    begin
      Name := 'swBotsVS';
      AddItem(_lc[I_MENU_BOTS_VS_PLAYERS]);
      AddItem(_lc[I_MENU_BOTS_VS_MONSTERS]);
      AddItem(_lc[I_MENU_BOTS_VS_ALL]);
      ItemIndex := 2;
    end;
    with AddSwitch(_lc[I_MENU_FLAG_DROP]) do
    begin
      Name := 'swFlagDrop';
      AddItem(_lc[I_MENU_FLAG_THROW]);
      AddItem(_lc[I_MENU_YES]);
      AddItem(_lc[I_MENU_NO]);
      ItemIndex := 2;
    end;

    ReAlign();
  end;
  Menu.DefControl := 'mGameSetGameMenu';
  Menu.OnClose := ProcApplyGameSet;
  g_GUI_AddWindow(Menu);

  Menu := TGUIWindow.Create('TeamMenu');
  with TGUIMainMenu(Menu.AddChild(TGUIMainMenu.Create(gMenuFont, '', _lc[I_MENU_CHANGE_PLAYERS]))) do
  begin
    Name := 'mmTeamMenu';
    AddButton(@ProcJoinRed, _lc[I_MENU_JOIN_RED], '').Name := 'tmJoinRed';
    AddButton(@ProcJoinBlue, _lc[I_MENU_JOIN_BLUE], '').Name := 'tmJoinBlue';
    AddButton(@ProcJoinGame, _lc[I_MENU_JOIN_GAME], '').Name := 'tmJoinGame';
    AddButton(@ProcSwitchP2, _lc[I_MENU_ADD_PLAYER_2], '').Name := 'tmPlayer2';
    AddButton(@ProcSpectate, _lc[I_MENU_SPECTATE], '').Name := 'tmSpectate';
  end;
  Menu.DefControl := 'mmTeamMenu';
  Menu.OnShow := ProcChangePlayers;
  g_GUI_AddWindow(Menu);
end;

procedure g_Menu_Show_SaveMenu();
begin
  if g_Game_IsTestMap then
    Exit;
  if gGameSettings.GameType = GT_SINGLE then
    g_GUI_ShowWindow('GameSingleMenu')
  else
  begin
    if g_Game_IsClient then
      Exit
    else
      if g_Game_IsNet then
        Exit
      else
        g_GUI_ShowWindow('GameCustomMenu');
  end;
  g_GUI_ShowWindow('SaveMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Show_LoadMenu (standalone: Boolean=false);
begin
  if (g_ActiveWindow <> nil) and (g_ActiveWindow.name = 'LoadMenu') then exit; // nothing to do
  if gGameSettings.GameType = GT_SINGLE then
  begin
    if not standalone then g_GUI_ShowWindow('GameSingleMenu')
  end
  else
  begin
    if g_Game_IsClient then exit;
    if g_Game_IsNet then exit;
    if not standalone then g_GUI_ShowWindow('GameCustomMenu');
  end;
  g_GUI_ShowWindow('LoadMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Show_GameSetGame();
begin
  if gGameSettings.GameType = GT_SINGLE then
    g_GUI_ShowWindow('GameSingleMenu')
  else
  begin
    if g_Game_IsClient then
      Exit
    else
      if g_Game_IsNet then
        g_GUI_ShowWindow('GameServerMenu')
      else
        g_GUI_ShowWindow('GameCustomMenu');
  end;
  ReadGameSettings();
  g_GUI_ShowWindow('GameSetGameMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Show_OptionsVideo();
begin
  if gGameSettings.GameType = GT_SINGLE then
    g_GUI_ShowWindow('GameSingleMenu')
  else
  begin
    if g_Game_IsClient then
      g_GUI_ShowWindow('GameClientMenu')
    else
      if g_Game_IsNet then
        g_GUI_ShowWindow('GameServerMenu')
      else
        g_GUI_ShowWindow('GameCustomMenu');
  end;
  ReadOptions();
  g_GUI_ShowWindow('OptionsMenu');
  g_GUI_ShowWindow('OptionsVideoMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Show_OptionsSound();
begin
  if gGameSettings.GameType = GT_SINGLE then
    g_GUI_ShowWindow('GameSingleMenu')
  else
  begin
    if g_Game_IsClient then
      g_GUI_ShowWindow('GameClientMenu')
    else
      if g_Game_IsNet then
        g_GUI_ShowWindow('GameServerMenu')
      else
        g_GUI_ShowWindow('GameCustomMenu');
  end;
  ReadOptions();
  g_GUI_ShowWindow('OptionsMenu');
  g_GUI_ShowWindow('OptionsSoundMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Show_EndGameMenu();
begin
  g_GUI_ShowWindow('EndGameMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Show_QuitGameMenu();
begin
  g_GUI_ShowWindow('ExitMenu');
  g_Sound_PlayEx('MENU_OPEN');
end;

procedure g_Menu_Init();
begin
  MenuLoadData();
  CreateAllMenus();
end;

procedure g_Menu_Free();
begin
  MenuFreeData();
end;

procedure g_Menu_Reset();
var
  ex: Boolean;
begin
  g_GUI_SaveMenuPos();
  ex := g_GUI_Destroy();

  if ex then
  begin
    e_WriteLog('Recreating menu...', TMsgType.Notify);

    CreateAllMenus();

    if gDebugMode then
      g_Game_SetDebugMode();

    g_GUI_LoadMenuPos();
  end;
end;

end.
