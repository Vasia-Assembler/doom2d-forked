(* Copyright (C)  DooM 2D:Forever Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
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
unit g_triggers;

interface

uses
  MAPDEF, e_graphics, g_basic, g_sound,
  BinEditor, xdynrec;

type
  TActivator = record
    UID:     Word;
    TimeOut: Word;
  end;
  PTrigger = ^TTrigger;
  TTrigger = record
  public
    ID:               DWORD;
    ClientID:         DWORD;
    TriggerType:      Byte;
    X, Y:             Integer;
    Width, Height:    Word;
    Enabled:          Boolean;
    ActivateType:     Byte;
    Keys:             Byte;
    TexturePanelGUID: Integer;
    TexturePanelType: Word;

    TimeOut:          Word;
    ActivateUID:      Word;
    Activators:       array of TActivator;
    PlayerCollide:    Boolean;
    DoorTime:         Integer;
    PressTime:        Integer;
    PressCount:       Integer;
    SoundPlayCount:   Integer;
    Sound:            TPlayableSound;
    AutoSpawn:        Boolean;
    SpawnCooldown:    Integer;
    SpawnedCount:     Integer;
    ShotPanelType:    Word;
    ShotPanelTime:    Integer;
    ShotSightTime:    Integer;
    ShotSightTimeout: Integer;
    ShotSightTarget:  Word;
    ShotSightTargetN: Word;
    ShotAmmoCount:    Word;
    ShotReloadTime:   Integer;

    mapId: AnsiString; // trigger id, from map
    mapIndex: Integer; // index in fields['trigger'], used in save/load
    trigPanelGUID: Integer;

    //TrigData:             TTriggerData;
    trigData: TDynRecord; // triggerdata; owned by trigger

  public
    function trigCenter (): TDFPoint; inline;

  public
    property trigShotPanelGUID: Integer read trigPanelGUID write trigPanelGUID;
  end;

function g_Triggers_Create(Trigger: TTrigger; forceInternalIndex: Integer=-1): DWORD;
procedure g_Triggers_Update();
procedure g_Triggers_Press(ID: DWORD; ActivateType: Byte; ActivateUID: Word = 0);
function g_Triggers_PressR(X, Y: Integer; Width, Height: Word; UID: Word;
                           ActivateType: Byte; IgnoreList: DWArray = nil): DWArray;
procedure g_Triggers_PressL(X1, Y1, X2, Y2: Integer; UID: DWORD; ActivateType: Byte);
procedure g_Triggers_PressC(CX, CY: Integer; Radius: Word; UID: Word; ActivateType: Byte; IgnoreTrigger: Integer = -1);
procedure g_Triggers_OpenAll();
procedure g_Triggers_DecreaseSpawner(ID: DWORD);
procedure g_Triggers_Free();
procedure g_Triggers_SaveState(var Mem: TBinMemoryWriter);
procedure g_Triggers_LoadState(var Mem: TBinMemoryReader);


var
  gTriggerClientID: Integer = 0;
  gTriggers: array of TTrigger;
  gSecretsCount: Integer = 0;
  gMonstersSpawned: array of LongInt = nil;


implementation

uses
  Math,
  g_player, g_map, g_panel, g_gfx, g_game, g_textures,
  g_console, g_monsters, g_items, g_phys, g_weapons,
  wadreader, g_main, SysUtils, e_log, g_language,
  g_options, g_net, g_netmsg, utils, xparser;

const
  TRIGGER_SIGNATURE = $58475254; // 'TRGX'
  TRAP_DAMAGE = 1000;


function TTrigger.trigCenter (): TDFPoint; inline;
begin
  result := TDFPoint.Create(x+width div 2, y+height div 2);
end;


function FindTrigger (): DWORD;
var
  i: Integer;
begin
  for i := 0 to High(gTriggers) do
  begin
    if gTriggers[i].TriggerType = TRIGGER_NONE then begin result := i; exit; end;
  end;

  if (gTriggers = nil) then
  begin
    SetLength(gTriggers, 8);
    result := 0;
  end
  else
  begin
    result := Length(gTriggers);
    SetLength(gTriggers, result+8);
    for i := result to High(gTriggers) do gTriggers[i].TriggerType := TRIGGER_NONE;
  end;
end;


function tr_CloseDoor (PanelGUID: Integer; NoSound: Boolean; d2d: Boolean): Boolean;
var
  a, b, c: Integer;
  pan: TPanel;
  PanelID: Integer;
begin
  result := false;
  pan := g_Map_PanelByGUID(PanelGUID);
  if (pan = nil) or not pan.isGWall then exit; //!FIXME!TRIGANY!
  PanelID := pan.arrIdx;

  if not d2d then
  begin
    with gWalls[PanelID] do
    begin
      if g_CollidePlayer(X, Y, Width, Height) or g_Mons_IsAnyAliveAt(X, Y, Width, Height) then Exit;
      if not Enabled then
      begin
        if not NoSound then
        begin
          g_Sound_PlayExAt('SOUND_GAME_DOORCLOSE', X, Y);
          if g_Game_IsServer and g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_DOORCLOSE');
        end;
        g_Map_EnableWallGUID(PanelGUID);
        result := true;
      end;
    end;
  end
  else
  begin
    if (gDoorMap = nil) then exit;

    c := -1;
    for a := 0 to High(gDoorMap) do
    begin
      for b := 0 to High(gDoorMap[a]) do
      begin
        if gDoorMap[a, b] = DWORD(PanelID) then
        begin
          c := a;
          break;
        end;
      end;
      if (c <> -1) then break;
    end;
    if (c = -1) then exit;

    for b := 0 to High(gDoorMap[c]) do
    begin
      with gWalls[gDoorMap[c, b]] do
      begin
        if g_CollidePlayer(X, Y, Width, Height) or g_Mons_IsAnyAliveAt(X, Y, Width, Height) then exit;
      end;
    end;

    if not NoSound then
    begin
      for b := 0 to High(gDoorMap[c]) do
      begin
        if not gWalls[gDoorMap[c, b]].Enabled then
        begin
          with gWalls[PanelID] do
          begin
            g_Sound_PlayExAt('SOUND_GAME_DOORCLOSE', X, Y);
            if g_Game_IsServer and g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_DOORCLOSE');
          end;
          break;
        end;
      end;
    end;

    for b := 0 to High(gDoorMap[c]) do
    begin
      if not gWalls[gDoorMap[c, b]].Enabled then
      begin
        g_Map_EnableWall_XXX(gDoorMap[c, b]);
        result := true;
      end;
    end;
  end;
end;


procedure tr_CloseTrap (PanelGUID: Integer; NoSound: Boolean; d2d: Boolean);
var
  a, b, c: Integer;
  wx, wy, wh, ww: Integer;
  pan: TPanel;
  PanelID: Integer;

  function monsDamage (mon: TMonster): Boolean;
  begin
    result := false; // don't stop
    if g_Obj_Collide(wx, wy, ww, wh, @mon.Obj) then mon.Damage(TRAP_DAMAGE, 0, 0, 0, HIT_TRAP);
  end;

begin
  pan := g_Map_PanelByGUID(PanelGUID);
  {
  if (pan = nil) then
  begin
    e_LogWritefln('tr_CloseTrap: pguid=%s; NO PANEL!', [PanelGUID], MSG_WARNING);
  end
  else
  begin
    e_LogWritefln('tr_CloseTrap: pguid=%s; isGWall=%s; arrIdx=%s', [PanelGUID, pan.isGWall, pan.arrIdx]);
  end;
  }
  if (pan = nil) or not pan.isGWall then exit; //!FIXME!TRIGANY!
  PanelID := pan.arrIdx;

  if not d2d then
  begin
    with gWalls[PanelID] do
    begin
      if (not NoSound) and (not Enabled) then
      begin
        g_Sound_PlayExAt('SOUND_GAME_SWITCH1', X, Y);
        if g_Game_IsServer and g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_SWITCH1');
      end;
    end;

    wx := gWalls[PanelID].X;
    wy := gWalls[PanelID].Y;
    ww := gWalls[PanelID].Width;
    wh := gWalls[PanelID].Height;

    with gWalls[PanelID] do
    begin
      if gPlayers <> nil then
      begin
        for a := 0 to High(gPlayers) do
        begin
          if (gPlayers[a] <> nil) and gPlayers[a].alive and gPlayers[a].Collide(X, Y, Width, Height) then
          begin
            gPlayers[a].Damage(TRAP_DAMAGE, 0, 0, 0, HIT_TRAP);
          end;
        end;
      end;

      //g_Mons_ForEach(monsDamage);
      g_Mons_ForEachAliveAt(wx, wy, ww, wh, monsDamage);

      if not Enabled then g_Map_EnableWallGUID(PanelGUID);
    end;
  end
  else
  begin
    if (gDoorMap = nil) then exit;

    c := -1;
    for a := 0 to High(gDoorMap) do
    begin
      for b := 0 to High(gDoorMap[a]) do
      begin
        if gDoorMap[a, b] = DWORD(PanelID) then
        begin
          c := a;
          break;
        end;
      end;
      if (c <> -1) then break;
    end;
    if (c = -1) then exit;

    if not NoSound then
    begin
      for b := 0 to High(gDoorMap[c]) do
      begin
        if not gWalls[gDoorMap[c, b]].Enabled then
        begin
          with gWalls[PanelID] do
          begin
            g_Sound_PlayExAt('SOUND_GAME_SWITCH1', X, Y);
            if g_Game_IsServer and g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_SWITCH1');
          end;
          Break;
        end;
      end;
    end;

    for b := 0 to High(gDoorMap[c]) do
    begin
      wx := gWalls[gDoorMap[c, b]].X;
      wy := gWalls[gDoorMap[c, b]].Y;
      ww := gWalls[gDoorMap[c, b]].Width;
      wh := gWalls[gDoorMap[c, b]].Height;

      with gWalls[gDoorMap[c, b]] do
      begin
        if gPlayers <> nil then
        begin
          for a := 0 to High(gPlayers) do
          begin
            if (gPlayers[a] <> nil) and gPlayers[a].alive and gPlayers[a].Collide(X, Y, Width, Height) then
            begin
              gPlayers[a].Damage(TRAP_DAMAGE, 0, 0, 0, HIT_TRAP);
            end;
          end;
        end;

        //g_Mons_ForEach(monsDamage);
        g_Mons_ForEachAliveAt(wx, wy, ww, wh, monsDamage);
        (*
        if gMonsters <> nil then
          for a := 0 to High(gMonsters) do
            if (gMonsters[a] <> nil) and gMonsters[a].alive and
            g_Obj_Collide(X, Y, Width, Height, @gMonsters[a].Obj) then
              gMonsters[a].Damage(TRAP_DAMAGE, 0, 0, 0, HIT_TRAP);
        *)

        if not Enabled then g_Map_EnableWall_XXX(gDoorMap[c, b]);
      end;
    end;
  end;
end;


function tr_OpenDoor (PanelGUID: Integer; NoSound: Boolean; d2d: Boolean): Boolean;
var
  a, b, c: Integer;
  pan: TPanel;
  PanelID: Integer;
begin
  result := false;
  pan := g_Map_PanelByGUID(PanelGUID);
  if (pan = nil) or not pan.isGWall then exit; //!FIXME!TRIGANY!
  PanelID := pan.arrIdx;

  if not d2d then
  begin
    with gWalls[PanelID] do
    begin
      if Enabled then
      begin
        if not NoSound then
        begin
          g_Sound_PlayExAt('SOUND_GAME_DOOROPEN', X, Y);
          if g_Game_IsServer and g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_DOOROPEN');
        end;
        g_Map_DisableWallGUID(PanelGUID);
        result := true;
      end;
    end
  end
  else
  begin
    if (gDoorMap = nil) then exit;

    c := -1;
    for a := 0 to High(gDoorMap) do
    begin
      for b := 0 to High(gDoorMap[a]) do
      begin
        if gDoorMap[a, b] = DWORD(PanelID) then
        begin
          c := a;
          break;
        end;
      end;
      if (c <> -1) then break;
    end;
    if (c = -1) then exit;

    if not NoSound then
    begin
      for b := 0 to High(gDoorMap[c]) do
      begin
        if gWalls[gDoorMap[c, b]].Enabled then
        begin
          with gWalls[PanelID] do
          begin
            g_Sound_PlayExAt('SOUND_GAME_DOOROPEN', X, Y);
            if g_Game_IsServer and g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_DOOROPEN');
          end;
          break;
        end;
      end;
    end;

    for b := 0 to High(gDoorMap[c]) do
    begin
      if gWalls[gDoorMap[c, b]].Enabled then
      begin
        g_Map_DisableWall_XXX(gDoorMap[c, b]);
        result := true;
      end;
    end;
  end;
end;


function tr_SetLift (PanelGUID: Integer; d: Integer; NoSound: Boolean; d2d: Boolean): Boolean;
var
  a, b, c: Integer;
  t: Integer = 0;
  pan: TPanel;
  PanelID: Integer;
begin
  result := false;
  pan := g_Map_PanelByGUID(PanelGUID);
  if (pan = nil) or not pan.isGLift then exit; //!FIXME!TRIGANY!
  PanelID := pan.arrIdx;

  if (gLifts[PanelID].PanelType = PANEL_LIFTUP) or (gLifts[PanelID].PanelType = PANEL_LIFTDOWN) then
  begin
    case d of
      0: t := 0;
      1: t := 1;
      else t := IfThen(gLifts[PanelID].LiftType = 1, 0, 1);
    end
  end
  else if (gLifts[PanelID].PanelType = PANEL_LIFTLEFT) or (gLifts[PanelID].PanelType = PANEL_LIFTRIGHT) then
  begin
    case d of
      0: t := 2;
      1: t := 3;
      else t := IfThen(gLifts[PanelID].LiftType = 2, 3, 2);
    end;
  end;

  if not d2d then
  begin
    with gLifts[PanelID] do
    begin
      if (LiftType <> t) then
      begin
        g_Map_SetLiftGUID(PanelGUID, t); //???
        //if not NoSound then g_Sound_PlayExAt('SOUND_GAME_SWITCH0', X, Y);
        result := true;
      end;
    end;
  end
  else // ��� � D2d
  begin
    if (gLiftMap = nil) then exit;

    c := -1;
    for a := 0 to High(gLiftMap) do
    begin
      for b := 0 to High(gLiftMap[a]) do
      begin
        if (gLiftMap[a, b] = DWORD(PanelID)) then
        begin
          c := a;
          break;
        end;
      end;
      if (c <> -1) then break;
    end;
    if (c = -1) then exit;

    {if not NoSound then
      for b := 0 to High(gLiftMap[c]) do
        if gLifts[gLiftMap[c, b]].LiftType <> t then
        begin
          with gLifts[PanelID] do
            g_Sound_PlayExAt('SOUND_GAME_SWITCH0', X, Y);
          Break;
        end;}

    for b := 0 to High(gLiftMap[c]) do
    begin
      with gLifts[gLiftMap[c, b]] do
      begin
        if (LiftType <> t) then
        begin
          g_Map_SetLift_XXX(gLiftMap[c, b], t);
          result := true;
        end;
      end;
    end;
  end;
end;


function tr_SpawnShot (ShotType: Integer; wx, wy, dx, dy: Integer; ShotSound: Boolean; ShotTarget: Word): Integer;
var
  snd: string;
  Projectile: Boolean;
  TextureID: DWORD;
  Anim: TAnimation;
begin
  result := -1;
  TextureID := DWORD(-1);
  snd := 'SOUND_WEAPON_FIREROCKET';
  Projectile := true;

  case ShotType of
    TRIGGER_SHOT_PISTOL:
      begin
        g_Weapon_pistol(wx, wy, dx, dy, 0, True);
        snd := 'SOUND_WEAPON_FIREPISTOL';
        Projectile := False;
        if ShotSound then
        begin
          g_Player_CreateShell(wx, wy, 0, -2, SHELL_BULLET);
          if g_Game_IsNet then MH_SEND_Effect(wx, wy, 0, NET_GFX_SHELL1);
        end;
      end;

    TRIGGER_SHOT_BULLET:
      begin
        g_Weapon_mgun(wx, wy, dx, dy, 0, True);
        if gSoundEffectsDF then snd := 'SOUND_WEAPON_FIRECGUN'
        else snd := 'SOUND_WEAPON_FIREPISTOL';
        Projectile := False;
        if ShotSound then
        begin
          g_Player_CreateShell(wx, wy, 0, -2, SHELL_BULLET);
          if g_Game_IsNet then MH_SEND_Effect(wx, wy, 0, NET_GFX_SHELL1);
        end;
      end;

    TRIGGER_SHOT_SHOTGUN:
      begin
        g_Weapon_Shotgun(wx, wy, dx, dy, 0, True);
        snd := 'SOUND_WEAPON_FIRESHOTGUN';
        Projectile := False;
        if ShotSound then
        begin
          g_Player_CreateShell(wx, wy, 0, -2, SHELL_SHELL);
          if g_Game_IsNet then MH_SEND_Effect(wx, wy, 0, NET_GFX_SHELL2);
        end;
      end;

    TRIGGER_SHOT_SSG:
      begin
        g_Weapon_DShotgun(wx, wy, dx, dy, 0, True);
        snd := 'SOUND_WEAPON_FIRESHOTGUN2';
        Projectile := False;
        if ShotSound then
        begin
          g_Player_CreateShell(wx, wy, 0, -2, SHELL_SHELL);
          g_Player_CreateShell(wx, wy, 0, -2, SHELL_SHELL);
          if g_Game_IsNet then MH_SEND_Effect(wx, wy, 0, NET_GFX_SHELL3);
        end;
      end;

    TRIGGER_SHOT_IMP:
      begin
        g_Weapon_ball1(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREBALL';
      end;

    TRIGGER_SHOT_PLASMA:
      begin
        g_Weapon_Plasma(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREPLASMA';
      end;

    TRIGGER_SHOT_SPIDER:
      begin
        g_Weapon_aplasma(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREPLASMA';
      end;

    TRIGGER_SHOT_CACO:
      begin
        g_Weapon_ball2(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREBALL';
      end;

    TRIGGER_SHOT_BARON:
      begin
        g_Weapon_ball7(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREBALL';
      end;

    TRIGGER_SHOT_MANCUB:
      begin
        g_Weapon_manfire(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREBALL';
      end;

    TRIGGER_SHOT_REV:
      begin
        g_Weapon_revf(wx, wy, dx, dy, 0, ShotTarget, -1, True);
        snd := 'SOUND_WEAPON_FIREREV';
      end;

    TRIGGER_SHOT_ROCKET:
      begin
        g_Weapon_Rocket(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREROCKET';
      end;

    TRIGGER_SHOT_BFG:
      begin
        g_Weapon_BFGShot(wx, wy, dx, dy, 0, -1, True);
        snd := 'SOUND_WEAPON_FIREBFG';
      end;

    TRIGGER_SHOT_EXPL:
      begin
        if g_Frames_Get(TextureID, 'FRAMES_EXPLODE_ROCKET') then
        begin
          Anim := TAnimation.Create(TextureID, False, 6);
          Anim.Blending := False;
          g_GFX_OnceAnim(wx-64, wy-64, Anim);
          Anim.Free();
        end;
        Projectile := False;
        g_Weapon_Explode(wx, wy, 60, 0);
        snd := 'SOUND_WEAPON_EXPLODEROCKET';
      end;

    TRIGGER_SHOT_BFGEXPL:
      begin
        if g_Frames_Get(TextureID, 'FRAMES_EXPLODE_BFG') then
        begin
          Anim := TAnimation.Create(TextureID, False, 6);
          Anim.Blending := False;
          g_GFX_OnceAnim(wx-64, wy-64, Anim);
          Anim.Free();
        end;
        Projectile := False;
        g_Weapon_BFG9000(wx, wy, 0);
        snd := 'SOUND_WEAPON_EXPLODEBFG';
      end;

    else exit;
  end;

  if g_Game_IsNet and g_Game_IsServer then
  begin
    case ShotType of
      TRIGGER_SHOT_EXPL: MH_SEND_Effect(wx, wy, Byte(ShotSound), NET_GFX_EXPLODE);
      TRIGGER_SHOT_BFGEXPL: MH_SEND_Effect(wx, wy, Byte(ShotSound), NET_GFX_BFGEXPL);
      else
      begin
        if Projectile then MH_SEND_CreateShot(LastShotID);
        if ShotSound then MH_SEND_Sound(wx, wy, snd);
      end;
    end;
  end;

  if ShotSound then g_Sound_PlayExAt(snd, wx, wy);

  if Projectile then Result := LastShotID;
end;


procedure MakeShot (var Trigger: TTrigger; wx, wy, dx, dy: Integer; TargetUID: Word);
begin
  with Trigger do
  begin
    if (trigData.trigShotAmmo = 0) or ((trigData.trigShotAmmo > 0) and (ShotAmmoCount > 0)) then
    begin
      if (trigShotPanelGUID <> -1) and (ShotPanelTime = 0) then
      begin
        g_Map_SwitchTextureGUID(ShotPanelType, trigShotPanelGUID);
        ShotPanelTime := 4; // ����� �� ������� ��������
      end;

      if (trigData.trigShotIntSight > 0) then ShotSightTimeout := 180; // ~= 5 ������

      if (ShotAmmoCount > 0) then Dec(ShotAmmoCount);

      dx += Random(trigData.trigShotAccuracy)-Random(trigData.trigShotAccuracy);
      dy += Random(trigData.trigShotAccuracy)-Random(trigData.trigShotAccuracy);

      tr_SpawnShot(trigData.trigShotType, wx, wy, dx, dy, trigData.trigShotSound, TargetUID);
    end
    else
    begin
      if (trigData.trigShotIntReload > 0) and (ShotReloadTime = 0) then
      begin
        ShotReloadTime := trigData.trigShotIntReload; // ����� �� ����������� �����
      end;
    end;
  end;
end;


procedure tr_MakeEffect (X, Y, VX, VY: Integer; T, ST, CR, CG, CB: Byte; Silent, Send: Boolean);
var
  FramesID: DWORD;
  Anim: TAnimation;
begin
  if T = TRIGGER_EFFECT_PARTICLE then
  begin
    case ST of
      TRIGGER_EFFECT_SLIQUID:
      begin
             if (CR = 255) and (CG = 0) and (CB = 0) then g_GFX_SimpleWater(X, Y, 1, VX, VY, 1, 0, 0, 0)
        else if (CR = 0) and (CG = 255) and (CB = 0) then g_GFX_SimpleWater(X, Y, 1, VX, VY, 2, 0, 0, 0)
        else if (CR = 0) and (CG = 0) and (CB = 255) then g_GFX_SimpleWater(X, Y, 1, VX, VY, 3, 0, 0, 0)
        else g_GFX_SimpleWater(X, Y, 1, VX, VY, 0, 0, 0, 0);
      end;
      TRIGGER_EFFECT_LLIQUID: g_GFX_SimpleWater(X, Y, 1, VX, VY, 4, CR, CG, CB);
      TRIGGER_EFFECT_DLIQUID: g_GFX_SimpleWater(X, Y, 1, VX, VY, 5, CR, CG, CB);
      TRIGGER_EFFECT_BLOOD: g_GFX_Blood(X, Y, 1, VX, VY, 0, 0, CR, CG, CB);
      TRIGGER_EFFECT_SPARK: g_GFX_Spark(X, Y, 1, GetAngle2(VX, VY), 0, 0);
      TRIGGER_EFFECT_BUBBLE: g_GFX_Bubbles(X, Y, 1, 0, 0);
    end;
  end;

  if T = TRIGGER_EFFECT_ANIMATION then
  begin
    case ST of
      EFFECT_TELEPORT: begin
        if g_Frames_Get(FramesID, 'FRAMES_TELEPORT') then
        begin
          Anim := TAnimation.Create(FramesID, False, 3);
          if not Silent then g_Sound_PlayExAt('SOUND_GAME_TELEPORT', X, Y);
          g_GFX_OnceAnim(X-32, Y-32, Anim);
          Anim.Free();
        end;
        if Send and g_Game_IsServer and g_Game_IsNet then MH_SEND_Effect(X, Y, Byte(not Silent), NET_GFX_TELE);
      end;
      EFFECT_RESPAWN: begin
        if g_Frames_Get(FramesID, 'FRAMES_ITEM_RESPAWN') then
        begin
          Anim := TAnimation.Create(FramesID, False, 4);
          if not Silent then g_Sound_PlayExAt('SOUND_ITEM_RESPAWNITEM', X, Y);
          g_GFX_OnceAnim(X-16, Y-16, Anim);
          Anim.Free();
        end;
        if Send and g_Game_IsServer and g_Game_IsNet then MH_SEND_Effect(X-16, Y-16, Byte(not Silent), NET_GFX_RESPAWN);
      end;
      EFFECT_FIRE: begin
        if g_Frames_Get(FramesID, 'FRAMES_FIRE') then
        begin
          Anim := TAnimation.Create(FramesID, False, 4);
          if not Silent then g_Sound_PlayExAt('SOUND_FIRE', X, Y);
          g_GFX_OnceAnim(X-32, Y-128, Anim);
          Anim.Free();
        end;
        if Send and g_Game_IsServer and g_Game_IsNet then MH_SEND_Effect(X-32, Y-128, Byte(not Silent), NET_GFX_FIRE);
      end;
    end;
  end;
end;


function tr_Teleport (ActivateUID: Integer; TX, TY: Integer; TDir: Integer; Silent: Boolean; D2D: Boolean): Boolean;
var
  p: TPlayer;
  m: TMonster;
begin
  Result := False;
  if (ActivateUID < 0) or (ActivateUID > $FFFF) then Exit;
  case g_GetUIDType(ActivateUID) of
    UID_PLAYER:
      begin
        p := g_Player_Get(ActivateUID);
        if p = nil then Exit;
        if D2D then
        begin
          if p.TeleportTo(TX-(p.Obj.Rect.Width div 2), TY-p.Obj.Rect.Height, Silent, TDir) then result := true;
        end
        else
        begin
          if p.TeleportTo(TX, TY, Silent, TDir) then result := true;
        end;
      end;
    UID_MONSTER:
      begin
        m := g_Monsters_ByUID(ActivateUID);
        if m = nil then Exit;
        if D2D then
        begin
          if m.TeleportTo(TX-(m.Obj.Rect.Width div 2), TY-m.Obj.Rect.Height, Silent, TDir) then result := true;
        end
        else
        begin
          if m.TeleportTo(TX, TY, Silent, TDir) then result := true;
        end;
      end;
  end;
end;


function tr_Push (ActivateUID: Integer; VX, VY: Integer; ResetVel: Boolean): Boolean;
var
  p: TPlayer;
  m: TMonster;
begin
  result := true;
  if (ActivateUID < 0) or (ActivateUID > $FFFF) then exit;
  case g_GetUIDType(ActivateUID) of
    UID_PLAYER:
      begin
        p := g_Player_Get(ActivateUID);
        if p = nil then Exit;

        if ResetVel then
        begin
          p.GameVelX := 0;
          p.GameVelY := 0;
          p.GameAccelX := 0;
          p.GameAccelY := 0;
        end;

        p.Push(VX, VY);
      end;

    UID_MONSTER:
      begin
        m := g_Monsters_ByUID(ActivateUID);
        if m = nil then Exit;

        if ResetVel then
        begin
          m.GameVelX := 0;
          m.GameVelY := 0;
          m.GameAccelX := 0;
          m.GameAccelY := 0;
        end;

        m.Push(VX, VY);
      end;
  end;
end;


function tr_Message (MKind: Integer; MText: string; MSendTo: Integer; MTime: Integer; ActivateUID: Integer): Boolean;
var
  msg: string;
  p: TPlayer;
  i: Integer;
begin
  Result := True;
  if (ActivateUID < 0) or (ActivateUID > $FFFF) then Exit;
  msg := b_Text_Format(MText);
  case MSendTo of
    0: // activator
      begin
        if g_GetUIDType(ActivateUID) = UID_PLAYER then
        begin
          if g_Game_IsWatchedPlayer(ActivateUID) then
          begin
                 if MKind = 0 then g_Console_Add(msg, True)
            else if MKind = 1 then g_Game_Message(msg, MTime);
          end
          else
          begin
            p := g_Player_Get(ActivateUID);
            if g_Game_IsNet and (p.FClientID >= 0) then
            begin
                   if MKind = 0 then MH_SEND_Chat(msg, NET_CHAT_SYSTEM, p.FClientID)
              else if MKind = 1 then MH_SEND_GameEvent(NET_EV_BIGTEXT, MTime, msg, p.FClientID);
            end;
          end;
        end;
      end;

    1: // activator's team
      begin
        if g_GetUIDType(ActivateUID) = UID_PLAYER then
        begin
          p := g_Player_Get(ActivateUID);
          if g_Game_IsWatchedTeam(p.Team) then
          begin
                 if MKind = 0 then g_Console_Add(msg, True)
            else if MKind = 1 then g_Game_Message(msg, MTime);
          end;

          if g_Game_IsNet then
          begin
            for i := Low(gPlayers) to High(gPlayers) do
            begin
              if (gPlayers[i].Team = p.Team) and (gPlayers[i].FClientID >= 0) then
              begin
                     if MKind = 0 then MH_SEND_Chat(msg, NET_CHAT_SYSTEM, gPlayers[i].FClientID)
                else if MKind = 1 then MH_SEND_GameEvent(NET_EV_BIGTEXT, MTime, msg, gPlayers[i].FClientID);
              end;
            end;
          end;
        end;
      end;

    2: // activator's enemy team
      begin
        if g_GetUIDType(ActivateUID) = UID_PLAYER then
        begin
          p := g_Player_Get(ActivateUID);
          if g_Game_IsWatchedTeam(p.Team) then
          begin
                 if MKind = 0 then g_Console_Add(msg, True)
            else if MKind = 1 then g_Game_Message(msg, MTime);
          end;

          if g_Game_IsNet then
          begin
            for i := Low(gPlayers) to High(gPlayers) do
            begin
              if (gPlayers[i].Team <> p.Team) and (gPlayers[i].FClientID >= 0) then
              begin
                     if MKind = 0 then MH_SEND_Chat(msg, NET_CHAT_SYSTEM, gPlayers[i].FClientID)
                else if MKind = 1 then MH_SEND_GameEvent(NET_EV_BIGTEXT, MTime, msg, gPlayers[i].FClientID);
              end;
            end;
          end;
        end;
      end;

    3: // red team
      begin
        if g_Game_IsWatchedTeam(TEAM_RED) then
        begin
               if MKind = 0 then g_Console_Add(msg, True)
          else if MKind = 1 then g_Game_Message(msg, MTime);
        end;

        if g_Game_IsNet then
        begin
          for i := Low(gPlayers) to High(gPlayers) do
          begin
            if (gPlayers[i].Team = TEAM_RED) and (gPlayers[i].FClientID >= 0) then
            begin
                   if MKind = 0 then MH_SEND_Chat(msg, NET_CHAT_SYSTEM, gPlayers[i].FClientID)
              else if MKind = 1 then MH_SEND_GameEvent(NET_EV_BIGTEXT, MTime, msg, gPlayers[i].FClientID);
            end;
          end;
        end;
      end;

    4: // blue team
      begin
        if g_Game_IsWatchedTeam(TEAM_BLUE) then
        begin
               if MKind = 0 then g_Console_Add(msg, True)
          else if MKind = 1 then g_Game_Message(msg, MTime);
        end;

        if g_Game_IsNet then
        begin
          for i := Low(gPlayers) to High(gPlayers) do
          begin
            if (gPlayers[i].Team = TEAM_BLUE) and (gPlayers[i].FClientID >= 0) then
            begin
                   if MKind = 0 then MH_SEND_Chat(msg, NET_CHAT_SYSTEM, gPlayers[i].FClientID)
              else if MKind = 1 then MH_SEND_GameEvent(NET_EV_BIGTEXT, MTime, msg, gPlayers[i].FClientID);
            end;
          end;
        end;
      end;

    5: // everyone
      begin
             if MKind = 0 then g_Console_Add(msg, True)
        else if MKind = 1 then g_Game_Message(msg, MTime);

        if g_Game_IsNet then
        begin
               if MKind = 0 then MH_SEND_Chat(msg, NET_CHAT_SYSTEM)
          else if MKind = 1 then MH_SEND_GameEvent(NET_EV_BIGTEXT, MTime, msg);
        end;
      end;
  end;
end;


function tr_ShotAimCheck (var Trigger: TTrigger; Obj: PObj): Boolean;
begin
  result := false;
  with Trigger do
  begin
    if TriggerType <> TRIGGER_SHOT then Exit;
    result := (trigData.trigShotAim and TRIGGER_SHOT_AIM_ALLMAP > 0)
              or g_Obj_Collide(X, Y, Width, Height, Obj);
    if result and (trigData.trigShotAim and TRIGGER_SHOT_AIM_TRACE > 0) then
    begin
      result := g_TraceVector(trigData.trigShotPos.X, trigData.trigShotPos.Y,
                              Obj^.X + Obj^.Rect.X + (Obj^.Rect.Width div 2),
                              Obj^.Y + Obj^.Rect.Y + (Obj^.Rect.Height div 2));
    end;
  end;
end;


function ActivateTrigger (var Trigger: TTrigger; actType: Byte): Boolean;
var
  animonce: Boolean;
  p: TPlayer;
  m: TMonster;
  pan: TPanel;
  idx, k, wx, wy, xd, yd: Integer;
  iid: LongWord;
  coolDown: Boolean;
  pAngle: Real;
  FramesID: DWORD;
  Anim: TAnimation;
  UIDType: Byte;
  TargetUID: Word;
  it: PItem;
  mon: TMonster;

  function monsShotTarget (mon: TMonster): Boolean;
  begin
    result := false; // don't stop
    if mon.alive and tr_ShotAimCheck(Trigger, @(mon.Obj)) then
    begin
      xd := mon.GameX + mon.Obj.Rect.Width div 2;
      yd := mon.GameY + mon.Obj.Rect.Height div 2;
      TargetUID := mon.UID;
      result := true; // stop
    end;
  end;

  function monsShotTargetMonPlr (mon: TMonster): Boolean;
  begin
    result := false; // don't stop
    if mon.alive and tr_ShotAimCheck(Trigger, @(mon.Obj)) then
    begin
      xd := mon.GameX + mon.Obj.Rect.Width div 2;
      yd := mon.GameY + mon.Obj.Rect.Height div 2;
      TargetUID := mon.UID;
      result := true; // stop
    end;
  end;

  function monShotTargetPlrMon (mon: TMonster): Boolean;
  begin
    result := false; // don't stop
    if mon.alive and tr_ShotAimCheck(Trigger, @(mon.Obj)) then
    begin
      xd := mon.GameX + mon.Obj.Rect.Width div 2;
      yd := mon.GameY + mon.Obj.Rect.Height div 2;
      TargetUID := mon.UID;
      result := true; // stop
    end;
  end;

begin
  result := false;
  if g_Game_IsClient then exit;

  if not Trigger.Enabled then exit;
  if (Trigger.TimeOut <> 0) and (actType <> ACTIVATE_CUSTOM) then exit;
  if gLMSRespawn = LMS_RESPAWN_WARMUP then exit;

  animonce := False;

  coolDown := (actType <> 0);

  with Trigger do
  begin
    case TriggerType of
      TRIGGER_EXIT:
        begin
          g_Sound_PlayEx('SOUND_GAME_SWITCH0');
          if g_Game_IsNet then MH_SEND_Sound(X, Y, 'SOUND_GAME_SWITCH0');
          gExitByTrigger := True;
          g_Game_ExitLevel(trigData.trigMapName);
          TimeOut := 18;
          Result := True;

          Exit;
        end;

      TRIGGER_TELEPORT:
        begin
          Result := tr_Teleport(ActivateUID,
                                trigData.trigTargetPoint.X, trigData.trigTargetPoint.Y,
                                trigData.trigTlpDir, trigData.trigsilent_teleport,
                                trigData.trigd2d_teleport);
          TimeOut := 0;
        end;

      TRIGGER_OPENDOOR:
        begin
          Result := tr_OpenDoor(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors);
          TimeOut := 0;
        end;

      TRIGGER_CLOSEDOOR:
        begin
          Result := tr_CloseDoor(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors);
          TimeOut := 0;
        end;

      TRIGGER_DOOR, TRIGGER_DOOR5:
        begin
          pan := g_Map_PanelByGUID(trigPanelGUID);
          if (pan <> nil) and pan.isGWall then
          begin
            if gWalls[{trigPanelID}pan.arrIdx].Enabled then
            begin
              result := tr_OpenDoor(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors);
              if (TriggerType = TRIGGER_DOOR5) then DoorTime := 180;
            end
            else
            begin
              result := tr_CloseDoor(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors);
            end;

            if result then TimeOut := 18;
          end;
        end;

      TRIGGER_CLOSETRAP, TRIGGER_TRAP:
        begin
          tr_CloseTrap(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors);

          if TriggerType = TRIGGER_TRAP then
            begin
              DoorTime := 40;
              TimeOut := 76;
            end
          else
            begin
              DoorTime := -1;
              TimeOut := 0;
            end;

          Result := True;
        end;

      TRIGGER_PRESS, TRIGGER_ON, TRIGGER_OFF, TRIGGER_ONOFF:
        begin
          PressCount += 1;
          if PressTime = -1 then PressTime := trigData.trigWait;
          if coolDown then TimeOut := 18 else TimeOut := 0;
          Result := True;
        end;

      TRIGGER_SECRET:
        if g_GetUIDType(ActivateUID) = UID_PLAYER then
        begin
          Enabled := False;
          Result := True;
          if gLMSRespawn = LMS_RESPAWN_NONE then
          begin
            g_Player_Get(ActivateUID).GetSecret();
            Inc(gCoopSecretsFound);
            if g_Game_IsNet then MH_SEND_GameStats();
          end;
        end;

      TRIGGER_LIFTUP:
        begin
          Result := tr_SetLift(trigPanelGUID, 0, trigData.trigNoSound, trigData.trigd2d_doors);
          TimeOut := 0;

          if (not trigData.trigNoSound) and Result then begin
            g_Sound_PlayExAt('SOUND_GAME_SWITCH0',
                             X + (Width div 2),
                             Y + (Height div 2));
            if g_Game_IsServer and g_Game_IsNet then
              MH_SEND_Sound(X + (Width div 2),
                            Y + (Height div 2),
                            'SOUND_GAME_SWITCH0');
          end;
        end;

      TRIGGER_LIFTDOWN:
        begin
          Result := tr_SetLift(trigPanelGUID, 1, trigData.trigNoSound, trigData.trigd2d_doors);
          TimeOut := 0;

          if (not trigData.trigNoSound) and Result then begin
            g_Sound_PlayExAt('SOUND_GAME_SWITCH0',
                             X + (Width div 2),
                             Y + (Height div 2));
            if g_Game_IsServer and g_Game_IsNet then
              MH_SEND_Sound(X + (Width div 2),
                            Y + (Height div 2),
                            'SOUND_GAME_SWITCH0');
          end;
        end;

      TRIGGER_LIFT:
        begin
          Result := tr_SetLift(trigPanelGUID, 3, trigData.trigNoSound, trigData.trigd2d_doors);

          if Result then
          begin
            TimeOut := 18;

            if (not trigData.trigNoSound) and Result then begin
              g_Sound_PlayExAt('SOUND_GAME_SWITCH0',
                               X + (Width div 2),
                               Y + (Height div 2));
              if g_Game_IsServer and g_Game_IsNet then
                MH_SEND_Sound(X + (Width div 2),
                              Y + (Height div 2),
                              'SOUND_GAME_SWITCH0');
            end;
          end;
        end;

      TRIGGER_TEXTURE:
        begin
          if trigData.trigActivateOnce then
            begin
              Enabled := False;
              TriggerType := TRIGGER_NONE;
            end
          else
            if coolDown then
              TimeOut := 6
            else
              TimeOut := 0;

          animonce := trigData.trigAnimOnce;
          Result := True;
        end;

      TRIGGER_SOUND:
        begin
          if Sound <> nil then
          begin
            if trigData.trigSoundSwitch and Sound.IsPlaying() then
              begin // ����� ���������, ���� �����
                Sound.Stop();
                SoundPlayCount := 0;
                Result := True;
              end
            else // (not Data.SoundSwitch) or (not Sound.IsPlaying())
              if (trigData.trigPlayCount > 0) or (not Sound.IsPlaying()) then
                begin
                  if trigData.trigPlayCount > 0 then
                    SoundPlayCount := trigData.trigPlayCount
                  else // 0 - ������ ����������
                    SoundPlayCount := 1;
                  Result := True;
                end;
            if g_Game_IsNet then MH_SEND_TriggerSound(Trigger);
          end;
        end;

      TRIGGER_SPAWNMONSTER:
        if (trigData.trigMonType in [MONSTER_DEMON..MONSTER_MAN]) then
        begin
          Result := False;
          if (trigData.trigMonDelay > 0) and (actType <> ACTIVATE_CUSTOM) then
          begin
            AutoSpawn := not AutoSpawn;
            SpawnCooldown := 0;
            // ����������� ���������� - ������ ��������
            Result := True;
          end;

          if ((trigData.trigMonDelay = 0) and (actType <> ACTIVATE_CUSTOM))
          or ((trigData.trigMonDelay > 0) and (actType = ACTIVATE_CUSTOM)) then
            for k := 1 to trigData.trigMonCount do
            begin
              if (actType = ACTIVATE_CUSTOM) and (trigData.trigMonDelay > 0) then
                SpawnCooldown := trigData.trigMonDelay;
              if (trigData.trigMonMax > 0) and (SpawnedCount >= trigData.trigMonMax) then
                Break;

              mon := g_Monsters_Create(trigData.trigMonType,
                     trigData.trigMonPos.X, trigData.trigMonPos.Y,
                     TDirection(trigData.trigMonDir), True);

              Result := True;

            // ��������:
              if (trigData.trigMonHealth > 0) then
                mon.SetHealth(trigData.trigMonHealth);
            // ������������� ���������:
              mon.MonsterBehaviour := trigData.trigMonBehav;
              mon.FNoRespawn := True;
              if g_Game_IsNet then
                MH_SEND_MonsterSpawn(mon.UID);
            // ���� ������ ����, ���� ����:
              if trigData.trigMonActive then
                mon.WakeUp();

              if trigData.trigMonType <> MONSTER_BARREL then Inc(gTotalMonsters);

              if g_Game_IsNet then
              begin
                SetLength(gMonstersSpawned, Length(gMonstersSpawned)+1);
                gMonstersSpawned[High(gMonstersSpawned)] := mon.UID;
              end;

              if trigData.trigMonMax > 0 then
              begin
                mon.SpawnTrigger := ID;
                Inc(SpawnedCount);
              end;

              case trigData.trigMonEffect of
                EFFECT_TELEPORT: begin
                  if g_Frames_Get(FramesID, 'FRAMES_TELEPORT') then
                  begin
                    Anim := TAnimation.Create(FramesID, False, 3);
                    g_Sound_PlayExAt('SOUND_GAME_TELEPORT', trigData.trigMonPos.X, trigData.trigMonPos.Y);
                    g_GFX_OnceAnim(mon.Obj.X+mon.Obj.Rect.X+(mon.Obj.Rect.Width div 2)-32,
                                   mon.Obj.Y+mon.Obj.Rect.Y+(mon.Obj.Rect.Height div 2)-32, Anim);
                    Anim.Free();
                  end;
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_Effect(mon.Obj.X+mon.Obj.Rect.X+(mon.Obj.Rect.Width div 2)-32,
                                   mon.Obj.Y+mon.Obj.Rect.Y+(mon.Obj.Rect.Height div 2)-32, 1,
                                   NET_GFX_TELE);
                end;
                EFFECT_RESPAWN: begin
                  if g_Frames_Get(FramesID, 'FRAMES_ITEM_RESPAWN') then
                  begin
                    Anim := TAnimation.Create(FramesID, False, 4);
                    g_Sound_PlayExAt('SOUND_ITEM_RESPAWNITEM', trigData.trigMonPos.X, trigData.trigMonPos.Y);
                    g_GFX_OnceAnim(mon.Obj.X+mon.Obj.Rect.X+(mon.Obj.Rect.Width div 2)-16,
                                   mon.Obj.Y+mon.Obj.Rect.Y+(mon.Obj.Rect.Height div 2)-16, Anim);
                    Anim.Free();
                  end;
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_Effect(mon.Obj.X+mon.Obj.Rect.X+(mon.Obj.Rect.Width div 2)-16,
                                   mon.Obj.Y+mon.Obj.Rect.Y+(mon.Obj.Rect.Height div 2)-16, 1,
                                   NET_GFX_RESPAWN);
                end;
                EFFECT_FIRE: begin
                  if g_Frames_Get(FramesID, 'FRAMES_FIRE') then
                  begin
                    Anim := TAnimation.Create(FramesID, False, 4);
                    g_Sound_PlayExAt('SOUND_FIRE', trigData.trigMonPos.X, trigData.trigMonPos.Y);
                    g_GFX_OnceAnim(mon.Obj.X+mon.Obj.Rect.X+(mon.Obj.Rect.Width div 2)-32,
                                   mon.Obj.Y+mon.Obj.Rect.Y+mon.Obj.Rect.Height-128, Anim);
                    Anim.Free();
                  end;
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_Effect(mon.Obj.X+mon.Obj.Rect.X+(mon.Obj.Rect.Width div 2)-32,
                                   mon.Obj.Y+mon.Obj.Rect.Y+mon.Obj.Rect.Height-128, 1,
                                   NET_GFX_FIRE);
                end;
              end;
            end;
          if g_Game_IsNet then
          begin
            MH_SEND_GameStats();
            MH_SEND_CoopStats();
          end;

          if coolDown then
            TimeOut := 18
          else
            TimeOut := 0;
          // ���� ����������� �������������, �� ������ ��������
          if actType = ACTIVATE_CUSTOM then
            Result := False;
        end;

      TRIGGER_SPAWNITEM:
        if (trigData.trigItemType in [ITEM_MEDKIT_SMALL..ITEM_MAX]) then
        begin
          Result := False;
          if (trigData.trigItemDelay > 0) and (actType <> ACTIVATE_CUSTOM) then
          begin
            AutoSpawn := not AutoSpawn;
            SpawnCooldown := 0;
            // ����������� ���������� - ������ ��������
            Result := True;
          end;

          if ((trigData.trigItemDelay = 0) and (actType <> ACTIVATE_CUSTOM))
          or ((trigData.trigItemDelay > 0) and (actType = ACTIVATE_CUSTOM)) then
            if (not trigData.trigItemOnlyDM) or
               (gGameSettings.GameMode in [GM_DM, GM_TDM, GM_CTF]) then
              for k := 1 to trigData.trigItemCount do
              begin
                if (actType = ACTIVATE_CUSTOM) and (trigData.trigItemDelay > 0) then
                  SpawnCooldown := trigData.trigItemDelay;
                if (trigData.trigItemMax > 0) and (SpawnedCount >= trigData.trigItemMax) then
                  Break;

                iid := g_Items_Create(trigData.trigItemPos.X, trigData.trigItemPos.Y,
                  trigData.trigItemType, trigData.trigItemFalls, False, True);

                Result := True;

                if trigData.trigItemMax > 0 then
                begin
                  it := g_Items_ByIdx(iid);
                  it.SpawnTrigger := ID;
                  Inc(SpawnedCount);
                end;

                case trigData.trigItemEffect of
                  EFFECT_TELEPORT: begin
                    it := g_Items_ByIdx(iid);
                    if g_Frames_Get(FramesID, 'FRAMES_TELEPORT') then
                    begin
                      Anim := TAnimation.Create(FramesID, False, 3);
                      g_Sound_PlayExAt('SOUND_GAME_TELEPORT', trigData.trigItemPos.X, trigData.trigItemPos.Y);
                      g_GFX_OnceAnim(it.Obj.X+it.Obj.Rect.X+(it.Obj.Rect.Width div 2)-32,
                                     it.Obj.Y+it.Obj.Rect.Y+(it.Obj.Rect.Height div 2)-32, Anim);
                      Anim.Free();
                    end;
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_Effect(it.Obj.X+it.Obj.Rect.X+(it.Obj.Rect.Width div 2)-32,
                                     it.Obj.Y+it.Obj.Rect.Y+(it.Obj.Rect.Height div 2)-32, 1,
                                     NET_GFX_TELE);
                  end;
                  EFFECT_RESPAWN: begin
                    it := g_Items_ByIdx(iid);
                    if g_Frames_Get(FramesID, 'FRAMES_ITEM_RESPAWN') then
                    begin
                      Anim := TAnimation.Create(FramesID, False, 4);
                      g_Sound_PlayExAt('SOUND_ITEM_RESPAWNITEM', trigData.trigItemPos.X, trigData.trigItemPos.Y);
                      g_GFX_OnceAnim(it.Obj.X+it.Obj.Rect.X+(it.Obj.Rect.Width div 2)-16,
                                     it.Obj.Y+it.Obj.Rect.Y+(it.Obj.Rect.Height div 2)-16, Anim);
                      Anim.Free();
                    end;
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_Effect(it.Obj.X+it.Obj.Rect.X+(it.Obj.Rect.Width div 2)-16,
                                     it.Obj.Y+it.Obj.Rect.Y+(it.Obj.Rect.Height div 2)-16, 1,
                                     NET_GFX_RESPAWN);
                  end;
                  EFFECT_FIRE: begin
                    it := g_Items_ByIdx(iid);
                    if g_Frames_Get(FramesID, 'FRAMES_FIRE') then
                    begin
                      Anim := TAnimation.Create(FramesID, False, 4);
                      g_Sound_PlayExAt('SOUND_FIRE', trigData.trigItemPos.X, trigData.trigItemPos.Y);
                      g_GFX_OnceAnim(it.Obj.X+it.Obj.Rect.X+(it.Obj.Rect.Width div 2)-32,
                                     it.Obj.Y+it.Obj.Rect.Y+it.Obj.Rect.Height-128, Anim);
                      Anim.Free();
                    end;
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_Effect(it.Obj.X+it.Obj.Rect.X+(it.Obj.Rect.Width div 2)-32,
                                     it.Obj.Y+it.Obj.Rect.Y+it.Obj.Rect.Height-128, 1,
                                     NET_GFX_FIRE);
                  end;
                end;

                if g_Game_IsNet then
                  MH_SEND_ItemSpawn(True, iid);
              end;

          if coolDown then
            TimeOut := 18
          else
            TimeOut := 0;
          // ���� ����������� �������������, �� ������ ��������
          if actType = ACTIVATE_CUSTOM then
            Result := False;
        end;

      TRIGGER_MUSIC:
        begin
        // ������ ������, ���� ���� �� ���:
          if (Trigger.trigData.trigMusicName <> '') then
          begin
            gMusic.SetByName(Trigger.trigData.trigMusicName);
            gMusic.SpecPause := True;
            gMusic.Play();
          end;

          if Trigger.trigData.trigMusicAction = 1 then
            begin // ��������
              if gMusic.SpecPause then // ���� �� ����� => ������
                gMusic.SpecPause := False
              else // ������ => �������
                gMusic.SetPosition(0);
            end
          else // ���������
            begin
            // �����:
              gMusic.SpecPause := True;
            end;

          if coolDown then
            TimeOut := 36
          else
            TimeOut := 0;
          Result := True;
          if g_Game_IsNet then MH_SEND_TriggerMusic;
        end;

      TRIGGER_PUSH:
        begin
          pAngle := -DegToRad(trigData.trigPushAngle);
          Result := tr_Push(ActivateUID,
                            Floor(Cos(pAngle)*trigData.trigPushForce),
                            Floor(Sin(pAngle)*trigData.trigPushForce),
                            trigData.trigResetVel);
          TimeOut := 0;
        end;

      TRIGGER_SCORE:
        begin
          Result := False;
          // ��������� ��� ������ ����
          if (trigData.trigScoreAction in [0..1]) and (trigData.trigScoreCount > 0) then
          begin
            // ����� ��� ����� �������
            if (trigData.trigScoreTeam in [0..1]) and (g_GetUIDType(ActivateUID) = UID_PLAYER) then
            begin
              p := g_Player_Get(ActivateUID);
              if ((trigData.trigScoreAction = 0) and (trigData.trigScoreTeam = 0) and (p.Team = TEAM_RED))
              or ((trigData.trigScoreAction = 0) and (trigData.trigScoreTeam = 1) and (p.Team = TEAM_BLUE)) then
              begin
                Inc(gTeamStat[TEAM_RED].Goals, trigData.trigScoreCount); // Red Scores

                if trigData.trigScoreCon then
                  if trigData.trigScoreTeam = 0 then
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_ADD_OWN], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '+r');
                  end else
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_ADD_ENEMY], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '+re');
                  end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_ADD], [AnsiUpperCase(_lc[I_GAME_TEAM_RED])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, TEAM_RED);
                end;
              end;
              if ((trigData.trigScoreAction = 1) and (trigData.trigScoreTeam = 0) and (p.Team = TEAM_RED))
              or ((trigData.trigScoreAction = 1) and (trigData.trigScoreTeam = 1) and (p.Team = TEAM_BLUE)) then
              begin
                Dec(gTeamStat[TEAM_RED].Goals, trigData.trigScoreCount); // Red Fouls

                if trigData.trigScoreCon then
                  if trigData.trigScoreTeam = 0 then
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_SUB_OWN], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '-r');
                  end else
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_SUB_ENEMY], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '-re');
                  end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_SUB], [AnsiUpperCase(_lc[I_GAME_TEAM_RED])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, -TEAM_RED);
                end;
              end;
              if ((trigData.trigScoreAction = 0) and (trigData.trigScoreTeam = 0) and (p.Team = TEAM_BLUE))
              or ((trigData.trigScoreAction = 0) and (trigData.trigScoreTeam = 1) and (p.Team = TEAM_RED)) then
              begin
                Inc(gTeamStat[TEAM_BLUE].Goals, trigData.trigScoreCount); // Blue Scores

                if trigData.trigScoreCon then
                  if trigData.trigScoreTeam = 0 then
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_ADD_OWN], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '+b');
                  end else
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_ADD_ENEMY], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '+be');
                  end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_ADD], [AnsiUpperCase(_lc[I_GAME_TEAM_BLUE])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, TEAM_BLUE);
                end;
              end;
              if ((trigData.trigScoreAction = 1) and (trigData.trigScoreTeam = 0) and (p.Team = TEAM_BLUE))
              or ((trigData.trigScoreAction = 1) and (trigData.trigScoreTeam = 1) and (p.Team = TEAM_RED)) then
              begin
                Dec(gTeamStat[TEAM_BLUE].Goals, trigData.trigScoreCount); // Blue Fouls

                if trigData.trigScoreCon then
                  if trigData.trigScoreTeam = 0 then
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_SUB_OWN], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '-b');
                  end else
                  begin
                    g_Console_Add(Format(_lc[I_PLAYER_SCORE_SUB_ENEMY], [p.Name, trigData.trigScoreCount, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                    if g_Game_IsServer and g_Game_IsNet then
                      MH_SEND_GameEvent(NET_EV_SCORE, p.UID or (trigData.trigScoreCount shl 16), '-be');
                  end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_SUB], [AnsiUpperCase(_lc[I_GAME_TEAM_BLUE])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, -TEAM_BLUE);
                end;
              end;
              Result := (p.Team = TEAM_RED) or (p.Team = TEAM_BLUE);
            end;
            // �����-�� ���������� �������
            if trigData.trigScoreTeam in [2..3] then
            begin
              if (trigData.trigScoreAction = 0) and (trigData.trigScoreTeam = 2) then
              begin
                Inc(gTeamStat[TEAM_RED].Goals, trigData.trigScoreCount); // Red Scores

                if trigData.trigScoreCon then
                begin
                  g_Console_Add(Format(_lc[I_PLAYER_SCORE_ADD_TEAM], [_lc[I_PLAYER_SCORE_RED], trigData.trigScoreCount]), True);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE, trigData.trigScoreCount shl 16, '+tr');
                end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_ADD], [AnsiUpperCase(_lc[I_GAME_TEAM_RED])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, TEAM_RED);
                end;
              end;
              if (trigData.trigScoreAction = 1) and (trigData.trigScoreTeam = 2) then
              begin
                Dec(gTeamStat[TEAM_RED].Goals, trigData.trigScoreCount); // Red Fouls

                if trigData.trigScoreCon then
                begin
                  g_Console_Add(Format(_lc[I_PLAYER_SCORE_SUB_TEAM], [_lc[I_PLAYER_SCORE_RED], trigData.trigScoreCount]), True);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE, trigData.trigScoreCount shl 16, '-tr');
                end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_SUB], [AnsiUpperCase(_lc[I_GAME_TEAM_RED])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, -TEAM_RED);
                end;
              end;
              if (trigData.trigScoreAction = 0) and (trigData.trigScoreTeam = 3) then
              begin
                Inc(gTeamStat[TEAM_BLUE].Goals, trigData.trigScoreCount); // Blue Scores

                if trigData.trigScoreCon then
                begin
                  g_Console_Add(Format(_lc[I_PLAYER_SCORE_ADD_TEAM], [_lc[I_PLAYER_SCORE_BLUE], trigData.trigScoreCount]), True);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE, trigData.trigScoreCount shl 16, '+tb');
                end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_ADD], [AnsiUpperCase(_lc[I_GAME_TEAM_BLUE])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, TEAM_BLUE);
                end;
              end;
              if (trigData.trigScoreAction = 1) and (trigData.trigScoreTeam = 3) then
              begin
                Dec(gTeamStat[TEAM_BLUE].Goals, trigData.trigScoreCount); // Blue Fouls

                if trigData.trigScoreCon then
                begin
                  g_Console_Add(Format(_lc[I_PLAYER_SCORE_SUB_TEAM], [_lc[I_PLAYER_SCORE_BLUE], trigData.trigScoreCount]), True);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE, trigData.trigScoreCount shl 16, '-tb');
                end;

                if trigData.trigScoreMsg then
                begin
                  g_Game_Message(Format(_lc[I_MESSAGE_SCORE_SUB], [AnsiUpperCase(_lc[I_GAME_TEAM_BLUE])]), 108);
                  if g_Game_IsServer and g_Game_IsNet then
                    MH_SEND_GameEvent(NET_EV_SCORE_MSG, -TEAM_BLUE);
                end;
              end;
              Result := True;
            end;
          end;
          // �������
          if (trigData.trigScoreAction = 2) and (gGameSettings.GoalLimit > 0) then
          begin
            // ����� ��� ����� �������
            if (trigData.trigScoreTeam in [0..1]) and (g_GetUIDType(ActivateUID) = UID_PLAYER) then
            begin
              p := g_Player_Get(ActivateUID);
              if ((trigData.trigScoreTeam = 0) and (p.Team = TEAM_RED)) // Red Wins
              or ((trigData.trigScoreTeam = 1) and (p.Team = TEAM_BLUE)) then
                if gTeamStat[TEAM_RED].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_RED].Goals := gGameSettings.GoalLimit;

                  if trigData.trigScoreCon then
                    if trigData.trigScoreTeam = 0 then
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_OWN], [p.Name, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wr');
                    end else
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_ENEMY], [p.Name, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wre');
                    end;

                  Result := True;
                end;
              if ((trigData.trigScoreTeam = 0) and (p.Team = TEAM_BLUE)) // Blue Wins
              or ((trigData.trigScoreTeam = 1) and (p.Team = TEAM_RED)) then
                if gTeamStat[TEAM_BLUE].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_BLUE].Goals := gGameSettings.GoalLimit;

                  if trigData.trigScoreCon then
                    if trigData.trigScoreTeam = 0 then
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_OWN], [p.Name, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wb');
                    end else
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_ENEMY], [p.Name, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wbe');
                    end;

                  Result := True;
                end;
            end;
            // �����-�� ���������� �������
            if trigData.trigScoreTeam in [2..3] then
            begin
              if trigData.trigScoreTeam = 2 then // Red Wins
                if gTeamStat[TEAM_RED].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_RED].Goals := gGameSettings.GoalLimit;
                  Result := True;
                end;
              if trigData.trigScoreTeam = 3 then // Blue Wins
                if gTeamStat[TEAM_BLUE].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_BLUE].Goals := gGameSettings.GoalLimit;
                  Result := True;
                end;
            end;
          end;
          // ��������
          if (trigData.trigScoreAction = 3) and (gGameSettings.GoalLimit > 0) then
          begin
            // ����� ��� ����� �������
            if (trigData.trigScoreTeam in [0..1]) and (g_GetUIDType(ActivateUID) = UID_PLAYER) then
            begin
              p := g_Player_Get(ActivateUID);
              if ((trigData.trigScoreTeam = 0) and (p.Team = TEAM_BLUE)) // Red Wins
              or ((trigData.trigScoreTeam = 1) and (p.Team = TEAM_RED)) then
                if gTeamStat[TEAM_RED].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_RED].Goals := gGameSettings.GoalLimit;

                  if trigData.trigScoreCon then
                    if trigData.trigScoreTeam = 0 then
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_ENEMY], [p.Name, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wre');
                    end else
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_OWN], [p.Name, _lc[I_PLAYER_SCORE_TO_RED]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wr');
                    end;

                  Result := True;
                end;
              if ((trigData.trigScoreTeam = 0) and (p.Team = TEAM_RED)) // Blue Wins
              or ((trigData.trigScoreTeam = 1) and (p.Team = TEAM_BLUE)) then
                if gTeamStat[TEAM_BLUE].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_BLUE].Goals := gGameSettings.GoalLimit;

                  if trigData.trigScoreCon then
                    if trigData.trigScoreTeam = 0 then
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_ENEMY], [p.Name, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wbe');
                    end else
                    begin
                      g_Console_Add(Format(_lc[I_PLAYER_SCORE_WIN_OWN], [p.Name, _lc[I_PLAYER_SCORE_TO_BLUE]]), True);
                      if g_Game_IsServer and g_Game_IsNet then
                        MH_SEND_GameEvent(NET_EV_SCORE, p.UID, 'wb');
                    end;

                  Result := True;
                end;
            end;
            // �����-�� ���������� �������
            if trigData.trigScoreTeam in [2..3] then
            begin
              if trigData.trigScoreTeam = 3 then // Red Wins
                if gTeamStat[TEAM_RED].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_RED].Goals := gGameSettings.GoalLimit;
                  Result := True;
                end;
              if trigData.trigScoreTeam = 2 then // Blue Wins
                if gTeamStat[TEAM_BLUE].Goals < SmallInt(gGameSettings.GoalLimit) then
                begin
                  gTeamStat[TEAM_BLUE].Goals := gGameSettings.GoalLimit;
                  Result := True;
                end;
            end;
          end;
          if Result then begin
            if coolDown then
              TimeOut := 18
            else
              TimeOut := 0;
            if g_Game_IsServer and g_Game_IsNet then
              MH_SEND_GameStats;
          end;
        end;

      TRIGGER_MESSAGE:
        begin
          Result := tr_Message(trigData.trigMessageKind, trigData.trigMessageText,
                               trigData.trigMessageSendTo, trigData.trigMessageTime,
                               ActivateUID);
          TimeOut := 18;
        end;

      TRIGGER_DAMAGE, TRIGGER_HEALTH:
        begin
          Result := False;
          UIDType := g_GetUIDType(ActivateUID);
          if (UIDType = UID_PLAYER) or (UIDType = UID_MONSTER) then
          begin
            Result := True;
            k := -1;
            if coolDown then
            begin
              // ����������, ����������� �� �� ���� ������
              for idx := 0 to High(Activators) do
                if Activators[idx].UID = ActivateUID then
                begin
                  k := idx;
                  Break;
                end;
              if k = -1 then
              begin // ����� ��� �������
                // ���������� ���
                SetLength(Activators, Length(Activators) + 1);
                k := High(Activators);
                Activators[k].UID := ActivateUID;
              end else
              begin // ��� ������ ���
                // ���� �������� ��������, �� �� �� ��� � ���� ���������, ��� ��� �����
                if (trigData.trigDamageInterval = 0) and (Activators[k].TimeOut > 0) then
                  Activators[k].TimeOut := 65535;
                // ������� ������ - ��������
                Result := Activators[k].TimeOut = 0;
              end;
            end;

            if Result then
            begin
              case UIDType of
                UID_PLAYER:
                  begin
                    p := g_Player_Get(ActivateUID);
                    if p = nil then
                      Exit;

                    // ������� ���� ������
                    if (TriggerType = TRIGGER_DAMAGE) and (trigData.trigDamageValue > 0) then
                      p.Damage(trigData.trigDamageValue, 0, 0, 0, HIT_SOME);

                    // ����� ������
                    if (TriggerType = TRIGGER_HEALTH) and (trigData.trigHealValue > 0) then
                      if p.Heal(trigData.trigHealValue, not trigData.trigHealMax) and (not trigData.trigHealSilent) then
                      begin
                        g_Sound_PlayExAt('SOUND_ITEM_GETITEM', p.Obj.X, p.Obj.Y);
                        if g_Game_IsServer and g_Game_IsNet then
                          MH_SEND_Sound(p.Obj.X, p.Obj.Y, 'SOUND_ITEM_GETITEM');
                      end;
                  end;

                UID_MONSTER:
                  begin
                    m := g_Monsters_ByUID(ActivateUID);
                    if m = nil then
                      Exit;

                    // ������� ���� �������
                    if (TriggerType = TRIGGER_DAMAGE) and (trigData.trigDamageValue > 0) then
                      m.Damage(trigData.trigDamageValue, 0, 0, 0, HIT_SOME);

                    // ����� �������
                    if (TriggerType = TRIGGER_HEALTH) and (trigData.trigHealValue > 0) then
                      if m.Heal(trigData.trigHealValue) and (not trigData.trigHealSilent) then
                      begin
                        g_Sound_PlayExAt('SOUND_ITEM_GETITEM', m.Obj.X, m.Obj.Y);
                        if g_Game_IsServer and g_Game_IsNet then
                          MH_SEND_Sound(m.Obj.X, m.Obj.Y, 'SOUND_ITEM_GETITEM');
                      end;
                  end;
              end;
              // ��������� ����� ���������� �����������
              if TriggerType = TRIGGER_DAMAGE then
                idx := trigData.trigDamageInterval
              else
                idx := trigData.trigHealInterval;
              if coolDown then
                if idx > 0 then
                  Activators[k].TimeOut := idx
                else
                  Activators[k].TimeOut := 65535;
            end;
          end;
          TimeOut := 0;
        end;

      TRIGGER_SHOT:
        begin
          if ShotSightTime > 0 then
            Exit;

          // put this at the beginning so it doesn't trigger itself
          TimeOut := trigData.trigShotWait + 1;

          wx := trigData.trigShotPos.X;
          wy := trigData.trigShotPos.Y;
          pAngle := -DegToRad(trigData.trigShotAngle);
          xd := wx + Round(Cos(pAngle) * 32.0);
          yd := wy + Round(Sin(pAngle) * 32.0);
          TargetUID := 0;

          case trigData.trigShotTarget of
            TRIGGER_SHOT_TARGET_MON: // monsters
              //TODO: accelerate this!
              g_Mons_ForEachAlive(monsShotTarget);

            TRIGGER_SHOT_TARGET_PLR: // players
              if gPlayers <> nil then
                for idx := Low(gPlayers) to High(gPlayers) do
                  if (gPlayers[idx] <> nil) and gPlayers[idx].alive and
                     tr_ShotAimCheck(Trigger, @(gPlayers[idx].Obj)) then
                  begin
                    xd := gPlayers[idx].GameX + PLAYER_RECT_CX;
                    yd := gPlayers[idx].GameY + PLAYER_RECT_CY;
                    TargetUID := gPlayers[idx].UID;
                    break;
                  end;

            TRIGGER_SHOT_TARGET_RED: // red team
              if gPlayers <> nil then
                for idx := Low(gPlayers) to High(gPlayers) do
                  if (gPlayers[idx] <> nil) and gPlayers[idx].alive and
                     (gPlayers[idx].Team = TEAM_RED) and
                     tr_ShotAimCheck(Trigger, @(gPlayers[idx].Obj)) then
                  begin
                    xd := gPlayers[idx].GameX + PLAYER_RECT_CX;
                    yd := gPlayers[idx].GameY + PLAYER_RECT_CY;
                    TargetUID := gPlayers[idx].UID;
                    break;
                  end;

            TRIGGER_SHOT_TARGET_BLUE: // blue team
              if gPlayers <> nil then
                for idx := Low(gPlayers) to High(gPlayers) do
                  if (gPlayers[idx] <> nil) and gPlayers[idx].alive and
                     (gPlayers[idx].Team = TEAM_BLUE) and
                     tr_ShotAimCheck(Trigger, @(gPlayers[idx].Obj)) then
                  begin
                    xd := gPlayers[idx].GameX + PLAYER_RECT_CX;
                    yd := gPlayers[idx].GameY + PLAYER_RECT_CY;
                    TargetUID := gPlayers[idx].UID;
                    break;
                  end;

            TRIGGER_SHOT_TARGET_MONPLR: // monsters then players
            begin
              //TODO: accelerate this!
              g_Mons_ForEachAlive(monsShotTargetMonPlr);

              if (TargetUID = 0) and (gPlayers <> nil) then
                for idx := Low(gPlayers) to High(gPlayers) do
                  if (gPlayers[idx] <> nil) and gPlayers[idx].alive and
                     tr_ShotAimCheck(Trigger, @(gPlayers[idx].Obj)) then
                  begin
                    xd := gPlayers[idx].GameX + PLAYER_RECT_CX;
                    yd := gPlayers[idx].GameY + PLAYER_RECT_CY;
                    TargetUID := gPlayers[idx].UID;
                    break;
                  end;
            end;

            TRIGGER_SHOT_TARGET_PLRMON: // players then monsters
            begin
              if gPlayers <> nil then
                for idx := Low(gPlayers) to High(gPlayers) do
                  if (gPlayers[idx] <> nil) and gPlayers[idx].alive and
                     tr_ShotAimCheck(Trigger, @(gPlayers[idx].Obj)) then
                  begin
                    xd := gPlayers[idx].GameX + PLAYER_RECT_CX;
                    yd := gPlayers[idx].GameY + PLAYER_RECT_CY;
                    TargetUID := gPlayers[idx].UID;
                    break;
                  end;
              if TargetUID = 0 then
              begin
                //TODO: accelerate this!
                g_Mons_ForEachAlive(monShotTargetPlrMon);
              end;
            end;

            else begin
              if (trigData.trigShotTarget <> TRIGGER_SHOT_TARGET_NONE) or
                 (trigData.trigShotType <> TRIGGER_SHOT_REV) then
                TargetUID := ActivateUID;
            end;
          end;

          if (trigData.trigShotTarget = TRIGGER_SHOT_TARGET_NONE) or (TargetUID > 0) or
            ((trigData.trigShotTarget > TRIGGER_SHOT_TARGET_NONE) and (TargetUID = 0)) then
          begin
            Result := True;
            if (trigData.trigShotIntSight = 0) or
               (trigData.trigShotTarget = TRIGGER_SHOT_TARGET_NONE) or
               (TargetUID = ShotSightTarget) then
              MakeShot(Trigger, wx, wy, xd, yd, TargetUID)
            else
            begin
              ShotSightTime := trigData.trigShotIntSight;
              ShotSightTargetN := TargetUID;
              if trigData.trigShotType = TRIGGER_SHOT_BFG then
              begin
                g_Sound_PlayExAt('SOUND_WEAPON_STARTFIREBFG', wx, wy);
                if g_Game_IsNet and g_Game_IsServer then
                  MH_SEND_Sound(wx, wy, 'SOUND_WEAPON_STARTFIREBFG');
              end;
            end;
          end;
        end;

      TRIGGER_EFFECT:
        begin
          idx := trigData.trigFXCount;

          while idx > 0 do
          begin
            case trigData.trigFXPos of
              TRIGGER_EFFECT_POS_CENTER:
              begin
                wx := X + Width div 2;
                wy := Y + Height div 2;
              end;
              TRIGGER_EFFECT_POS_AREA:
              begin
                wx := X + Random(Width);
                wy := Y + Random(Height);
              end;
              else begin
                wx := X + Width div 2;
                wy := Y + Height div 2;
              end;
            end;
            xd := trigData.trigFXVelX;
            yd := trigData.trigFXVelY;
            if trigData.trigFXSpreadL > 0 then xd := xd - Random(trigData.trigFXSpreadL + 1);
            if trigData.trigFXSpreadR > 0 then xd := xd + Random(trigData.trigFXSpreadR + 1);
            if trigData.trigFXSpreadU > 0 then yd := yd - Random(trigData.trigFXSpreadU + 1);
            if trigData.trigFXSpreadD > 0 then yd := yd + Random(trigData.trigFXSpreadD + 1);
            tr_MakeEffect(wx, wy, xd, yd,
                       trigData.trigFXType, trigData.trigFXSubType,
                       trigData.trigFXColorR, trigData.trigFXColorG, trigData.trigFXColorB, True, False);
            Dec(idx);
          end;
          TimeOut := trigData.trigFXWait;
        end;
    end;
  end;

  if Result {and (Trigger.TexturePanel <> -1)} then
  begin
    g_Map_SwitchTextureGUID(Trigger.TexturePanelType, Trigger.TexturePanelGUID, IfThen(animonce, 2, 1));
  end;
end;


function g_Triggers_CreateWithMapIndex (Trigger: TTrigger; arridx, mapidx: Integer): DWORD;
var
  triggers: TDynField;
begin
  triggers := gCurrentMap['trigger'];
  if (triggers = nil) then raise Exception.Create('LOAD: map has no triggers');
  if (mapidx < 0) or (mapidx >= triggers.count) then raise Exception.Create('LOAD: invalid map trigger index');
  Trigger.trigData := triggers.item[mapidx];
  if (Trigger.trigData = nil) then raise Exception.Create('LOAD: internal error in trigger loader');
  Trigger.mapId := Trigger.trigData.id;
  Trigger.mapIndex := mapidx;
  if (Trigger.trigData.trigRec <> nil) then
  begin
    Trigger.trigData := Trigger.trigData.trigRec.clone({Trigger.trigData.headerRec}nil);
  end
  else
  begin
    Trigger.trigData := nil;
  end;
  result := g_Triggers_Create(Trigger, arridx);
end;


function g_Triggers_Create(Trigger: TTrigger; forceInternalIndex: Integer=-1): DWORD;
var
  find_id: DWORD;
  fn, mapw: AnsiString;
  f, olen: Integer;
begin
// �� ��������� �����, ���� ���� ��� ������:
  if (Trigger.TriggerType = TRIGGER_EXIT) and
     (not LongBool(gGameSettings.Options and GAME_OPTION_ALLOWEXIT)) then
    Trigger.TriggerType := TRIGGER_NONE;

// ���� ������� ���������, �������� �������:
  if (Trigger.TriggerType = TRIGGER_SPAWNMONSTER) and
     (not LongBool(gGameSettings.Options and GAME_OPTION_MONSTERS)) and
     (gGameSettings.GameType <> GT_SINGLE) then
    Trigger.TriggerType := TRIGGER_NONE;

// ������� ���������� �������� �� �����:
  if Trigger.TriggerType = TRIGGER_SECRET then
    gSecretsCount := gSecretsCount + 1;

  if (forceInternalIndex < 0) then
  begin
    find_id := FindTrigger();
  end
  else
  begin
    olen := Length(gTriggers);
    if (forceInternalIndex >= olen) then
    begin
      SetLength(gTriggers, forceInternalIndex+1);
      for f := olen to High(gTriggers) do gTriggers[f].TriggerType := TRIGGER_NONE;
    end;
    find_id := DWORD(forceInternalIndex);
  end;
  gTriggers[find_id] := Trigger;

  //e_LogWritefln('created trigger with map index %s, findid=%s (%s)', [Trigger.mapIndex, find_id, Trigger.mapId]);

  {
  writeln('trigger #', find_id, ': pos=(', Trigger.x, ',', Trigger.y, ')-(', Trigger.width, 'x', Trigger.height, ')',
    '; TexturePanel=', Trigger.TexturePanel,
    '; TexturePanelType=', Trigger.TexturePanelType,
    '; ShotPanelType=', Trigger.ShotPanelType,
    '; TriggerType=', Trigger.TriggerType,
    '; ActivateType=', Trigger.ActivateType,
    '; Keys=', Trigger.Keys,
    '; trigPanelId=', Trigger.trigPanelId,
    '; trigShotPanelId=', Trigger.trigShotPanelId
    );
  }

  with gTriggers[find_id] do
  begin
    ID := find_id;
    // if this type of trigger exists both on the client and on the server
    // use an uniform numeration
    if Trigger.TriggerType = TRIGGER_SOUND then
    begin
      Inc(gTriggerClientID);
      ClientID := gTriggerClientID;
    end
    else
      ClientID := 0;
    TimeOut := 0;
    ActivateUID := 0;
    PlayerCollide := False;
    DoorTime := -1;
    PressTime := -1;
    PressCount := 0;
    SoundPlayCount := 0;
    Sound := nil;
    AutoSpawn := False;
    SpawnCooldown := 0;
    SpawnedCount := 0;
  end;

// ��������� ����, ���� ��� ������� "����":
  if (Trigger.TriggerType = TRIGGER_SOUND) and
     (Trigger.trigData.trigSoundName <> '') then
  begin
  // ��� ��� ������ �����:
    if not g_Sound_Exists(Trigger.trigData.trigSoundName) then
    begin
      fn := g_ExtractWadName(Trigger.trigData.trigSoundName);

      if fn = '' then
        begin // ���� � ����� � ������
          mapw := g_ExtractWadName(gMapInfo.Map);
          fn := mapw+':'+g_ExtractFilePathName(Trigger.trigData.trigSoundName);
        end
      else // ���� � ��������� �����
        fn := GameDir + '/wads/' + Trigger.trigData.trigSoundName;

      if not g_Sound_CreateWADEx(Trigger.trigData.trigSoundName, fn) then
        g_FatalError(Format(_lc[I_GAME_ERROR_TR_SOUND], [fn, Trigger.trigData.trigSoundName]));
    end;

  // ������� ������ �����:
    with gTriggers[find_id] do
    begin
      Sound := TPlayableSound.Create();
      if not Sound.SetByName(Trigger.trigData.trigSoundName) then
      begin
        Sound.Free();
        Sound := nil;
      end;
    end;
  end;

// ��������� ������, ���� ��� ������� "������":
  if (Trigger.TriggerType = TRIGGER_MUSIC) and
     (Trigger.trigData.trigMusicName <> '') then
  begin
  // ��� ��� ����� ������:
    if not g_Sound_Exists(Trigger.trigData.trigMusicName) then
    begin
      fn := g_ExtractWadName(Trigger.trigData.trigMusicName);

      if fn = '' then
        begin // ������ � ����� � ������
          mapw := g_ExtractWadName(gMapInfo.Map);
          fn := mapw+':'+g_ExtractFilePathName(Trigger.trigData.trigMusicName);
        end
      else // ������ � ����� � ������
        fn := GameDir+'/wads/'+Trigger.trigData.trigMusicName;

      if not g_Sound_CreateWADEx(Trigger.trigData.trigMusicName, fn, True) then
        g_FatalError(Format(_lc[I_GAME_ERROR_TR_SOUND], [fn, Trigger.trigData.trigMusicName]));
    end;
  end;

// ��������� ������ �������� "������":
  if Trigger.TriggerType = TRIGGER_SHOT then
    with gTriggers[find_id] do
    begin
      ShotPanelTime := 0;
      ShotSightTime := 0;
      ShotSightTimeout := 0;
      ShotSightTarget := 0;
      ShotSightTargetN := 0;
      ShotAmmoCount := Trigger.trigData.trigShotAmmo;
      ShotReloadTime := 0;
    end;

  Result := find_id;
end;


// sorry; grid doesn't support recursive queries, so we have to do this
type
  TSimpleMonsterList = specialize TSimpleList<TMonster>;

var
  tgMonsList: TSimpleMonsterList = nil;

procedure g_Triggers_Update();
var
  a, b, i: Integer;
  Affected: array of Integer;

  function monsNear (mon: TMonster): Boolean;
  begin
    result := false; // don't stop
    {
    gTriggers[a].ActivateUID := mon.UID;
    ActivateTrigger(gTriggers[a], ACTIVATE_MONSTERCOLLIDE);
    }
    tgMonsList.append(mon);
  end;

var
  mon: TMonster;
  pan: TPanel;
begin
  if (tgMonsList = nil) then tgMonsList := TSimpleMonsterList.Create();

  if gTriggers = nil then
    Exit;
  SetLength(Affected, 0);

  for a := 0 to High(gTriggers) do
    with gTriggers[a] do
    // ���� �������:
      if TriggerType <> TRIGGER_NONE then
      begin
        // ��������� ����� �� �������� ����� (�������� �������)
        if DoorTime > 0 then DoorTime := DoorTime - 1;
        // ��������� ����� �������� ����� �������
        if PressTime > 0 then PressTime := PressTime - 1;
        // ��������� ������� � ��������, ������� ����� ���������:
        if (TriggerType = TRIGGER_DAMAGE) or (TriggerType = TRIGGER_HEALTH) then
        begin
          for b := 0 to High(Activators) do
          begin
            // ��������� ����� �� ���������� �����������:
            if Activators[b].TimeOut > 0 then
            begin
              Dec(Activators[b].TimeOut);
            end
            else
            begin
              continue;
            end;
            // �������, ��� ������ ������� ���� �������� ��������
            if (trigData.trigDamageInterval = 0) and (Activators[b].TimeOut < 65530) then Activators[b].TimeOut := 0;
          end;
        end;

        // ������������ ��������
        if Enabled and AutoSpawn then
        begin
          if SpawnCooldown = 0 then
          begin
            // ���� ������ �����, ������� �������
            if (TriggerType = TRIGGER_SPAWNMONSTER) and (trigData.trigMonDelay > 0)  then
            begin
              ActivateUID := 0;
              ActivateTrigger(gTriggers[a], ACTIVATE_CUSTOM);
            end;
            // ���� ������ �����, ������� �������
            if (TriggerType = TRIGGER_SPAWNITEM) and (trigData.trigItemDelay > 0) then
            begin
              ActivateUID := 0;
              ActivateTrigger(gTriggers[a], ACTIVATE_CUSTOM);
            end;
          end
          else
          begin
            // ��������� ����� ��������
            Dec(SpawnCooldown);
          end;
        end;

        // ������������ ������� �������� "������"
        if TriggerType = TRIGGER_SHOT then
        begin
          if ShotPanelTime > 0 then
          begin
            Dec(ShotPanelTime);
            if ShotPanelTime = 0 then g_Map_SwitchTextureGUID(ShotPanelType, trigShotPanelGUID);
          end;
          if ShotSightTime > 0 then
          begin
            Dec(ShotSightTime);
            if ShotSightTime = 0 then ShotSightTarget := ShotSightTargetN;
          end;
          if ShotSightTimeout > 0 then
          begin
            Dec(ShotSightTimeout);
            if ShotSightTimeout = 0 then ShotSightTarget := 0;
          end;
          if ShotReloadTime > 0 then
          begin
            Dec(ShotReloadTime);
            if ShotReloadTime = 0 then ShotAmmoCount := trigData.trigShotAmmo;
          end;
        end;

        // ������� "����" ��� �������, ���� ����� ��� - �������������
        if Enabled and (TriggerType = TRIGGER_SOUND) and (Sound <> nil) then
        begin
          if (SoundPlayCount > 0) and (not Sound.IsPlaying()) then
          begin
            if trigData.trigPlayCount > 0 then SoundPlayCount -= 1; // ���� 0 - ������ ���� ����������
            if trigData.trigLocal then
            begin
              Sound.PlayVolumeAt(X+(Width div 2), Y+(Height div 2), trigData.trigVolume/255.0);
            end
            else
            begin
              Sound.PlayPanVolume((trigData.trigPan-127.0)/128.0, trigData.trigVolume/255.0);
            end;
            if Sound.IsPlaying() and g_Game_IsNet and g_Game_IsServer then MH_SEND_TriggerSound(gTriggers[a]);
          end;
        end;

        // ������� "�������" - ���� ���������
        if (TriggerType = TRIGGER_TRAP) and (DoorTime = 0) and (g_Map_PanelByGUID(trigPanelGUID) <> nil) then
        begin
          tr_OpenDoor(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors);
          DoorTime := -1;
        end;

        // ������� "����� 5 ���" - ���� ���������
        if (TriggerType = TRIGGER_DOOR5) and (DoorTime = 0) and (g_Map_PanelByGUID(trigPanelGUID) <> nil) then
        begin
          pan := g_Map_PanelByGUID(trigPanelGUID);
          if (pan <> nil) and pan.isGWall then
          begin
            // ��� �������
            if {gWalls[trigPanelID].Enabled} pan.Enabled then
            begin
              DoorTime := -1;
            end
            else
            begin
              // ���� ������� - ���������
              if tr_CloseDoor(trigPanelGUID, trigData.trigNoSound, trigData.trigd2d_doors) then DoorTime := -1;
            end;
          end;
        end;

      // ������� - ����������� ��� �������������, � ������ ��������, � ������ ������ ����� ���:
        if (TriggerType in [TRIGGER_PRESS, TRIGGER_ON, TRIGGER_OFF, TRIGGER_ONOFF]) and
           (PressTime = 0) and (PressCount >= trigData.trigCount) then
        begin
          // ���������� �������� ���������:
          PressTime := -1;
          // ���������� ������� �������:
          if trigData.trigCount > 0 then PressCount -= trigData.trigCount else PressCount := 0;

          // ���������� ���������� �� ��������:
          for b := 0 to High(gTriggers) do
          begin
            if g_Collide(trigData.trigtX, trigData.trigtY, trigData.trigtWidth, trigData.trigtHeight, gTriggers[b].X, gTriggers[b].Y,
               gTriggers[b].Width, gTriggers[b].Height) and
               ((b <> a) or (trigData.trigWait > 0)) then
            begin // Can be self-activated, if there is Data.Wait
              if (not trigData.trigExtRandom) or gTriggers[b].Enabled then
              begin
                SetLength(Affected, Length(Affected) + 1);
                Affected[High(Affected)] := b;
              end;
            end;
          end;

          //HACK!
          // if we have panelid, assume that it will switch the moving platform
          pan := g_Map_PanelByGUID(trigPanelGUID);
          if (pan <> nil) then
          begin
            case TriggerType of
              TRIGGER_PRESS: pan.movingActive := true; // what to do here?
              TRIGGER_ON: pan.movingActive := true;
              TRIGGER_OFF: pan.movingActive := false;
              TRIGGER_ONOFF: pan.movingActive := not pan.movingActive;
            end;
          end;

          // �������� ���� �� ��������� ��� �����������, ���� ������� ������:
          if (TriggerType = TRIGGER_PRESS) and trigData.trigExtRandom then
          begin
            if (Length(Affected) > 0) then
            begin
              b := Affected[Random(Length(Affected))];
              gTriggers[b].ActivateUID := gTriggers[a].ActivateUID;
              ActivateTrigger(gTriggers[b], 0);
            end;
          end
          else // � ��������� ������ �������� ��� ������:
          begin
            for i := 0 to High(Affected) do
            begin
              b := Affected[i];
              case TriggerType of
                TRIGGER_PRESS:
                  begin
                    gTriggers[b].ActivateUID := gTriggers[a].ActivateUID;
                    ActivateTrigger(gTriggers[b], 0);
                  end;
                TRIGGER_ON:
                  begin
                    gTriggers[b].Enabled := True;
                  end;
                TRIGGER_OFF:
                  begin
                    gTriggers[b].Enabled := False;
                    gTriggers[b].TimeOut := 0;
                    if gTriggers[b].AutoSpawn then
                    begin
                      gTriggers[b].AutoSpawn := False;
                      gTriggers[b].SpawnCooldown := 0;
                    end;
                  end;
                TRIGGER_ONOFF:
                  begin
                    gTriggers[b].Enabled := not gTriggers[b].Enabled;
                    if not gTriggers[b].Enabled then
                    begin
                      gTriggers[b].TimeOut := 0;
                      if gTriggers[b].AutoSpawn then
                      begin
                        gTriggers[b].AutoSpawn := False;
                        gTriggers[b].SpawnCooldown := 0;
                      end;
                    end;
                  end;
              end;
            end;
          end;
          SetLength(Affected, 0);
        end;

      // ��������� ����� �� ����������� ��������� ���������:
        if TimeOut > 0 then
        begin
          TimeOut := TimeOut - 1;
          Continue; // ����� �� �������� 1 ������� ��������
        end;

      // ���� ���� ���� ���������, ���� ������� �������� - ��� ������
        if not Enabled then
          Continue;

      // "����� ������":
        if ByteBool(ActivateType and ACTIVATE_PLAYERCOLLIDE) and
           (TimeOut = 0) then
          if gPlayers <> nil then
            for b := 0 to High(gPlayers) do
              if gPlayers[b] <> nil then
                with gPlayers[b] do
                // ���, ���� ������ ����� � �� �����:
                  if alive and ((gTriggers[a].Keys and GetKeys) = gTriggers[a].Keys) and
                     Collide(X, Y, Width, Height) then
                  begin
                    gTriggers[a].ActivateUID := UID;

                    if (gTriggers[a].TriggerType in [TRIGGER_SOUND, TRIGGER_MUSIC]) and
                       PlayerCollide then
                      { Don't activate sound/music again if player is here }
                    else
                      ActivateTrigger(gTriggers[a], ACTIVATE_PLAYERCOLLIDE);
                  end;

        { TODO 5 : ��������� ��������� ��������� � ������� }

        if ByteBool(ActivateType and ACTIVATE_MONSTERCOLLIDE) and
           ByteBool(ActivateType and ACTIVATE_NOMONSTER) and
           (TimeOut = 0) and (Keys = 0) then
        begin
        // ���� "������ ������" � "�������� ���",
        // ��������� ������� �� ������ ����� � ������� ��� �����
          ActivateType := ActivateType and not (ACTIVATE_MONSTERCOLLIDE or ACTIVATE_NOMONSTER);
          gTriggers[a].ActivateUID := 0;
          ActivateTrigger(gTriggers[a], 0);
        end else
        begin
          // "������ ������"
          if ByteBool(ActivateType and ACTIVATE_MONSTERCOLLIDE) and
             (TimeOut = 0) and (Keys = 0) then // ���� �� ����� �����
          begin
            //g_Mons_ForEach(monsNear);
            //Alive?!
            tgMonsList.reset();
            g_Mons_ForEachAt(gTriggers[a].X, gTriggers[a].Y, gTriggers[a].Width, gTriggers[a].Height, monsNear);
            for mon in tgMonsList do
            begin
              gTriggers[a].ActivateUID := mon.UID;
              ActivateTrigger(gTriggers[a], ACTIVATE_MONSTERCOLLIDE);
            end;
            tgMonsList.reset(); // just in case
          end;

          // "�������� ���"
          if ByteBool(ActivateType and ACTIVATE_NOMONSTER) and
             (TimeOut = 0) and (Keys = 0) then
            if not g_Mons_IsAnyAliveAt(X, Y, Width, Height) then
            begin
              gTriggers[a].ActivateUID := 0;
              ActivateTrigger(gTriggers[a], ACTIVATE_NOMONSTER);
            end;
        end;

        PlayerCollide := g_CollidePlayer(X, Y, Width, Height);
      end;
end;

procedure g_Triggers_Press(ID: DWORD; ActivateType: Byte; ActivateUID: Word = 0);
begin
  if (ID >= Length(gTriggers)) then exit;
  gTriggers[ID].ActivateUID := ActivateUID;
  ActivateTrigger(gTriggers[ID], ActivateType);
end;

function g_Triggers_PressR(X, Y: Integer; Width, Height: Word; UID: Word;
                           ActivateType: Byte; IgnoreList: DWArray = nil): DWArray;
var
  a: Integer;
  k: Byte;
  p: TPlayer;
begin
  Result := nil;

  if gTriggers = nil then Exit;

  case g_GetUIDType(UID) of
    UID_GAME: k := 255;
    UID_PLAYER:
    begin
      p := g_Player_Get(UID);
      if p <> nil then
        k := p.GetKeys
      else
        k := 0;
    end;
    else k := 0;
  end;

  for a := 0 to High(gTriggers) do
    if (gTriggers[a].TriggerType <> TRIGGER_NONE) and
       (gTriggers[a].TimeOut = 0) and
       (not InDWArray(a, IgnoreList)) and
       ((gTriggers[a].Keys and k) = gTriggers[a].Keys) and
       ByteBool(gTriggers[a].ActivateType and ActivateType) then
      if g_Collide(X, Y, Width, Height,
         gTriggers[a].X, gTriggers[a].Y,
         gTriggers[a].Width, gTriggers[a].Height) then
      begin
        gTriggers[a].ActivateUID := UID;
        if ActivateTrigger(gTriggers[a], ActivateType) then
        begin
          SetLength(Result, Length(Result)+1);
          Result[High(Result)] := a;
        end;
      end;
end;

procedure g_Triggers_PressL(X1, Y1, X2, Y2: Integer; UID: DWORD; ActivateType: Byte);
var
  a: Integer;
  k: Byte;
  p: TPlayer;
begin
  if gTriggers = nil then Exit;

  case g_GetUIDType(UID) of
    UID_GAME: k := 255;
    UID_PLAYER:
    begin
      p := g_Player_Get(UID);
      if p <> nil then
        k := p.GetKeys
      else
        k := 0;
    end;
    else k := 0;
  end;

  for a := 0 to High(gTriggers) do
    if (gTriggers[a].TriggerType <> TRIGGER_NONE) and
       (gTriggers[a].TimeOut = 0) and
       ((gTriggers[a].Keys and k) = gTriggers[a].Keys) and
       ByteBool(gTriggers[a].ActivateType and ActivateType) then
      if g_CollideLine(x1, y1, x2, y2, gTriggers[a].X, gTriggers[a].Y,
         gTriggers[a].Width, gTriggers[a].Height) then
      begin
        gTriggers[a].ActivateUID := UID;
        ActivateTrigger(gTriggers[a], ActivateType);
      end;
end;

procedure g_Triggers_PressC(CX, CY: Integer; Radius: Word; UID: Word; ActivateType: Byte; IgnoreTrigger: Integer = -1);
var
  a: Integer;
  k: Byte;
  rsq: Word;
  p: TPlayer;
begin
  if gTriggers = nil then
    Exit;

  case g_GetUIDType(UID) of
    UID_GAME: k := 255;
    UID_PLAYER:
    begin
     p := g_Player_Get(UID);
     if p <> nil then
      k := p.GetKeys
     else
      k := 0;
    end;
    else k := 0;
  end;

  rsq := Radius * Radius;

  for a := 0 to High(gTriggers) do
    if (gTriggers[a].ID <> DWORD(IgnoreTrigger)) and
       (gTriggers[a].TriggerType <> TRIGGER_NONE) and
       (gTriggers[a].TimeOut = 0) and
       ((gTriggers[a].Keys and k) = gTriggers[a].Keys) and
       ByteBool(gTriggers[a].ActivateType and ActivateType) then
      with gTriggers[a] do
        if g_Collide(CX-Radius, CY-Radius, 2*Radius, 2*Radius,
                     X, Y, Width, Height) then
          if ((Sqr(CX-X)+Sqr(CY-Y)) < rsq) or // ����� ����� ������ � �������� ������ ����
             ((Sqr(CX-X-Width)+Sqr(CY-Y)) < rsq) or // ����� ����� ������ � �������� ������� ����
             ((Sqr(CX-X-Width)+Sqr(CY-Y-Height)) < rsq) or // ����� ����� ������ � ������� ������� ����
             ((Sqr(CX-X)+Sqr(CY-Y-Height)) < rsq) or // ����� ����� ������ � ������� ������ ����
             ( (CX > (X-Radius)) and (CX < (X+Width+Radius)) and
               (CY > Y) and (CY < (Y+Height)) ) or // ����� ����� �������� �� ������������ ������ ��������������
             ( (CY > (Y-Radius)) and (CY < (Y+Height+Radius)) and
               (CX > X) and (CX < (X+Width)) ) then // ����� ����� �������� �� �������������� ������ ��������������
          begin
            ActivateUID := UID;
            ActivateTrigger(gTriggers[a], ActivateType);
          end;
end;

procedure g_Triggers_OpenAll();
var
  a: Integer;
  b: Boolean;
begin
  if gTriggers = nil then Exit;

  b := False;
  for a := 0 to High(gTriggers) do
  begin
    with gTriggers[a] do
    begin
      if (TriggerType = TRIGGER_OPENDOOR) or
         (TriggerType = TRIGGER_DOOR5) or
         (TriggerType = TRIGGER_DOOR) then
      begin
        tr_OpenDoor(trigPanelGUID, True, trigData.trigd2d_doors);
        if TriggerType = TRIGGER_DOOR5 then DoorTime := 180;
        b := True;
      end;
    end;
  end;

  if b then g_Sound_PlayEx('SOUND_GAME_DOOROPEN');
end;

procedure g_Triggers_DecreaseSpawner(ID: DWORD);
begin
  if (gTriggers <> nil) then
    if gTriggers[ID].SpawnedCount > 0 then
      Dec(gTriggers[ID].SpawnedCount);
end;

procedure g_Triggers_Free();
var
  a: Integer;
begin
  for a := 0 to High(gTriggers) do
  begin
    if (gTriggers[a].TriggerType = TRIGGER_SOUND) then
    begin
      if g_Sound_Exists(gTriggers[a].trigData.trigSoundName) then
      begin
        g_Sound_Delete(gTriggers[a].trigData.trigSoundName);
      end;
      gTriggers[a].Sound.Free();
    end;
    if (gTriggers[a].Activators <> nil) then
    begin
      SetLength(gTriggers[a].Activators, 0);
    end;
    gTriggers[a].trigData.Free();
  end;

  gTriggers := nil;
  gSecretsCount := 0;
  SetLength(gMonstersSpawned, 0);
end;

procedure g_Triggers_SaveState(var Mem: TBinMemoryWriter);
var
  count, act_count, i, j: Integer;
  dw: DWORD;
  sg: Single;
  b: Boolean;
begin
  // ������� ���������� ������������ ���������
  count := Length(gTriggers);

  Mem := TBinMemoryWriter.Create((count+1) * 200);

  // ���������� ���������:
  Mem.WriteInt(count);

  //e_LogWritefln('saving %s triggers (count=%s)', [Length(gTriggers), count]);

  if count = 0 then exit;

  for i := 0 to High(gTriggers) do
  begin
  // ��������� ��������:
    dw := TRIGGER_SIGNATURE; // 'TRGX'
    Mem.WriteDWORD(dw);
  // ��� ��������:
    Mem.WriteByte(gTriggers[i].TriggerType);
    if (gTriggers[i].TriggerType = TRIGGER_NONE) then continue; // empty one
  // ����������� ������ ��������: �� � ����, ����� �� ����� ����� �������; �������� ������ ������
    //e_LogWritefln('=== trigger #%s saved ===', [gTriggers[i].mapIndex]);
    Mem.WriteInt(gTriggers[i].mapIndex);
    //p := @gTriggers[i].Data;
    //Mem.WriteMemory(p, SizeOf(TTriggerData));
  // ���������� ������ �������� ����:
    Mem.WriteInt(gTriggers[i].X);
    Mem.WriteInt(gTriggers[i].Y);
  // �������:
    Mem.WriteWord(gTriggers[i].Width);
    Mem.WriteWord(gTriggers[i].Height);
  // ������� �� �������:
    Mem.WriteBoolean(gTriggers[i].Enabled);
  // ��� ��������� ��������:
    Mem.WriteByte(gTriggers[i].ActivateType);
  // �����, ����������� ��� ���������:
    Mem.WriteByte(gTriggers[i].Keys);
  // ID ������, �������� ������� ���������:
    Mem.WriteInt(gTriggers[i].TexturePanelGUID);
  // ��� ���� ������:
    Mem.WriteWord(gTriggers[i].TexturePanelType);
  // ���������� ����� ������ ������ (�� ���������� ����������� �� ����� ��������� � ���, ��� ������� ��� �������� �����)
    Mem.WriteInt(gTriggers[i].trigPanelGUID);
  // ����� �� ����������� ���������:
    Mem.WriteWord(gTriggers[i].TimeOut);
  // UID ����, ��� ����������� ���� �������:
    Mem.WriteWord(gTriggers[i].ActivateUID);
  // ������ UID-�� ��������, ������� ���������� ��� ������������:
    act_count := Length(gTriggers[i].Activators);
    Mem.WriteInt(act_count);
    for j := 0 to act_count-1 do
    begin
      // UID �������
      Mem.WriteWord(gTriggers[i].Activators[j].UID);
      // ����� ��������
      Mem.WriteWord(gTriggers[i].Activators[j].TimeOut);
    end;
  // ����� �� ����� � ������� ��������:
    Mem.WriteBoolean(gTriggers[i].PlayerCollide);
  // ����� �� �������� �����:
    Mem.WriteInt(gTriggers[i].DoorTime);
  // �������� ���������:
    Mem.WriteInt(gTriggers[i].PressTime);
  // ������� �������:
    Mem.WriteInt(gTriggers[i].PressCount);
  // ������� �������:
    Mem.WriteBoolean(gTriggers[i].AutoSpawn);
  // �������� ��������:
    Mem.WriteInt(gTriggers[i].SpawnCooldown);
  // ������� �������� ��������:
    Mem.WriteInt(gTriggers[i].SpawnedCount);
  // ������� ��� �������� ����:
    Mem.WriteInt(gTriggers[i].SoundPlayCount);
  // ������������� �� ����?
    if gTriggers[i].Sound <> nil then
      b := gTriggers[i].Sound.IsPlaying()
    else
      b := False;
    Mem.WriteBoolean(b);
    if b then
    begin
    // ������� ������������ �����:
      dw := gTriggers[i].Sound.GetPosition();
      Mem.WriteDWORD(dw);
    // ��������� �����:
      sg := gTriggers[i].Sound.GetVolume();
      sg := sg / (gSoundLevel/255.0);
      Mem.WriteSingle(sg);
    // ������ �������� �����:
      sg := gTriggers[i].Sound.GetPan();
      Mem.WriteSingle(sg);
    end;
  end;
end;

procedure g_Triggers_LoadState(var Mem: TBinMemoryReader);
var
  count, act_count, i, j, a: Integer;
  dw: DWORD;
  vol, pan: Single;
  b: Boolean;
  //p: Pointer;
  Trig: TTrigger;
  mapIndex: Integer;
  //tw: TStrTextWriter;
begin
  if Mem = nil then
    Exit;

  g_Triggers_Free();

// ���������� ���������:
  Mem.ReadInt(count);

  if (count = 0) then exit;

  for a := 0 to count-1 do
  begin
  // ��������� ��������:
    Mem.ReadDWORD(dw);
    if (dw <> TRIGGER_SIGNATURE) then // 'TRGX'
    begin
      raise EBinSizeError.Create('g_Triggers_LoadState: Wrong Trigger Signature');
    end;
  // ��� ��������:
    Mem.ReadByte(Trig.TriggerType);
  // ����������� ������ ��������: ������ � gCurrentMap.field['triggers']
    if (Trig.TriggerType = TRIGGER_NONE) then continue; // empty one
    Mem.ReadInt(mapIndex);
  //!!!FIXME!!!
    {
    Mem.ReadMemory(p, dw);
    if dw <> SizeOf(TTriggerData) then
    begin
      raise EBinSizeError.Create('g_Triggers_LoadState: Wrong TriggerData Size');
    end;
    Trig.Data := TTriggerData(p^);
    }
  // ������� �������:
    i := g_Triggers_CreateWithMapIndex(Trig, a, mapIndex);
    {
    if (gTriggers[i].trigData <> nil) then
    begin
      tw := TStrTextWriter.Create();
      try
        gTriggers[i].trigData.writeTo(tw);
        e_LogWritefln('=== trigger #%s loaded ==='#10'%s'#10'---', [mapIndex, tw.str]);
      finally
        tw.Free();
      end;
    end;
    }
  // ���������� ������ �������� ����:
    Mem.ReadInt(gTriggers[i].X);
    Mem.ReadInt(gTriggers[i].Y);
  // �������:
    Mem.ReadWord(gTriggers[i].Width);
    Mem.ReadWord(gTriggers[i].Height);
  // ������� �� �������:
    Mem.ReadBoolean(gTriggers[i].Enabled);
  // ��� ��������� ��������:
    Mem.ReadByte(gTriggers[i].ActivateType);
  // �����, ����������� ��� ���������:
    Mem.ReadByte(gTriggers[i].Keys);
  // ID ������, �������� ������� ���������:
    Mem.ReadInt(gTriggers[i].TexturePanelGUID);
  // ��� ���� ������:
    Mem.ReadWord(gTriggers[i].TexturePanelType);
  // ���������� ����� ������ ������ (�� ���������� ����������� �� ����� ��������� � ���, ��� ������� ��� �������� �����)
    Mem.ReadInt(gTriggers[i].trigPanelGUID);
  // ����� �� ����������� ���������:
    Mem.ReadWord(gTriggers[i].TimeOut);
  // UID ����, ��� ����������� ���� �������:
    Mem.ReadWord(gTriggers[i].ActivateUID);
  // ������ UID-�� ��������, ������� ���������� ��� ������������:
    Mem.ReadInt(act_count);
    if act_count > 0 then
    begin
      SetLength(gTriggers[i].Activators, act_count);
      for j := 0 to act_count-1 do
      begin
        // UID �������
        Mem.ReadWord(gTriggers[i].Activators[j].UID);
        // ����� ��������
        Mem.ReadWord(gTriggers[i].Activators[j].TimeOut);
      end;
    end;
  // ����� �� ����� � ������� ��������:
    Mem.ReadBoolean(gTriggers[i].PlayerCollide);
  // ����� �� �������� �����:
    Mem.ReadInt(gTriggers[i].DoorTime);
  // �������� ���������:
    Mem.ReadInt(gTriggers[i].PressTime);
  // ������� �������:
    Mem.ReadInt(gTriggers[i].PressCount);
  // ������� �������:
    Mem.ReadBoolean(gTriggers[i].AutoSpawn);
  // �������� ��������:
    Mem.ReadInt(gTriggers[i].SpawnCooldown);
  // ������� �������� ��������:
    Mem.ReadInt(gTriggers[i].SpawnedCount);
  // ������� ��� �������� ����:
    Mem.ReadInt(gTriggers[i].SoundPlayCount);
  // ������������� �� ����?
    Mem.ReadBoolean(b);
    if b then
    begin
    // ������� ������������ �����:
      Mem.ReadDWORD(dw);
    // ��������� �����:
      Mem.ReadSingle(vol);
    // ������ �������� �����:
      Mem.ReadSingle(pan);
    // ��������� ����, ���� ����:
      if gTriggers[i].Sound <> nil then
      begin
        gTriggers[i].Sound.PlayPanVolume(pan, vol);
        gTriggers[i].Sound.Pause(True);
        gTriggers[i].Sound.SetPosition(dw);
      end
    end;
  end;
end;

end.
