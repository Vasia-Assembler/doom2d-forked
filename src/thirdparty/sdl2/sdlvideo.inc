//from "sdl_video.h"

  {**
   *  The structure that defines a display mode
   *
   *   SDL_GetNumDisplayModes()
   *   SDL_GetDisplayMode()
   *   SDL_GetDesktopDisplayMode()
   *   SDL_GetCurrentDisplayMode()
   *   SDL_GetClosestDisplayMode()
   *   SDL_SetWindowDisplayMode()
   *   SDL_GetWindowDisplayMode()
   *}

  PSDL_DisplayMode = ^TSDL_DisplayMode;
  TSDL_DisplayMode = record
    format: UInt32;              {**< pixel format *}
    w: SInt32;                   {**< width *}
    h: SInt32;                   {**< height *}
    refresh_rate: SInt32;        {**< refresh rate (or zero for unspecified) *}
    driverdata: Pointer;         {**< driver-specific data, initialize to 0 *}
  end;

  {* Define the SDL window-shaper structure *}
  PSDL_WindowShaper = ^TSDL_WindowShaper;
  TSDL_WindowShaper = record
    {* The window associated with the shaper *}
    window: PSDL_Window;

    {* The user's specified coordinates for the window, for once we give it a shape. *}
    userx,usery: UInt32;

    {* The parameters for shape calculation. *}
    mode: TSDL_WindowShapeMode;

    {* Has this window been assigned a shape? *}
    hasshape: TSDL_Bool;

    driverdata: Pointer;
  end;

  PSDL_WindowUserData = ^TSDL_WindowUserData;
  TSDL_WindowUserData = record
    name: PAnsiChar;
    data: Pointer;
    next: PSDL_WindowUserData;
  end;

  {* Define the SDL window structure, corresponding to toplevel windows *}
  TSDL_Window = record
    magic: Pointer;
    id: UInt32;
    title: PAnsiChar;
    icon: PSDL_Surface;
    x,y: SInt32;
    w,h: SInt32;
    min_w, min_h: SInt32;
    max_w, max_h: SInt32;
    flags: UInt32;

    {* Stored position and size for windowed mode * }
    windowed: TSDL_Rect;

    fullscreen_mode: TSDL_DisplayMode;

    brightness: Float;
    gamma: PUInt16;
    saved_gamma: PUInt16;  {* (just offset into gamma) *}

    surface: PSDL_Surface;
    surface_valid: TSDL_Bool;

    shaper: PSDL_WindowShaper;

    data: PSDL_WindowUserData;

    driverdata: Pointer;

    prev: PSDL_Window;
    next: PSDL_Window;
  end;

  {**
   * Get the shape parameters of a shaped window.
   *
   *  window The shaped window whose parameters should be retrieved.
   *  shape_mode An empty shape-mode structure to fill, or NULL to check whether the window has a shape.
   *
   *  0 if the window has a shape and, provided shape_mode was not NULL, shape_mode has been filled with the mode
   *  data, SDL_NONSHAPEABLE_WINDOW if the SDL_Window given is not a shaped window, or SDL_WINDOW_LACKS_SHAPE if
   *  the SDL_Window* given is a shapeable window currently lacking a shape.
   *
   *  SDL_WindowShapeMode
   *  SDL_SetWindowShape
   *}
function SDL_GetShapedWindowMode(window: PSDL_Window; shape_mode: TSDL_WindowShapeMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetShapedWindowMode' {$ENDIF} {$ENDIF};

  {**
   * Set the shape and parameters of a shaped window.
   *
   *  window The shaped window whose parameters should be set.
   *  shape A surface encoding the desired shape for the window.
   *  shape_mode The parameters to set for the shaped window.
   *
   *  0 on success, SDL_INVALID_SHAPE_ARGUMENT on invalid an invalid shape argument, or SDL_NONSHAPEABLE_WINDOW
   *  if the SDL_Window* given does not reference a valid shaped window.
   *
   *  SDL_WindowShapeMode
   *  SDL_GetShapedWindowMode.
   *}
function SDL_SetWindowShape(window: PSDL_Window; shape: PSDL_Surface; shape_mode: PSDL_WindowShapeMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowShape' {$ENDIF} {$ENDIF};

  {**
   *  Create a window that can be shaped with the specified position, dimensions, and flags.
   *
   *   title The title of the window, in UTF-8 encoding.
   *   x     The x position of the window, ::SDL_WINDOWPOS_CENTERED, or
   *               ::SDL_WINDOWPOS_UNDEFINED.
   *   y     The y position of the window, ::SDL_WINDOWPOS_CENTERED, or
   *               ::SDL_WINDOWPOS_UNDEFINED.
   *   w     The width of the window.
   *   h     The height of the window.
   *   flags The flags for the window, a mask of SDL_WINDOW_BORDERLESS with any of the following:
   *         SDL_WINDOW_OPENGL,     SDL_WINDOW_INPUT_GRABBED,
   *         SDL_WINDOW_SHOWN,      SDL_WINDOW_RESIZABLE,
   *         SDL_WINDOW_MAXIMIZED,  SDL_WINDOW_MINIMIZED,
   *         SDL_WINDOW_BORDERLESS is always set, and SDL_WINDOW_FULLSCREEN is always unset.
   *
   *   The window created, or NULL if window creation failed.
   *
   *  SDL_DestroyWindow()
   *}
function SDL_CreateShapedWindow(title: PAnsiChar; x: UInt32; y: UInt32; w: UInt32; h: UInt32; flags: UInt32): PSDL_Window cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateShapedWindow' {$ENDIF} {$ENDIF};

  {**
   * Return whether the given window is a shaped window.
   *
   *  window The window to query for being shaped.
   *
   *  SDL_TRUE if the window is a window that can be shaped, SDL_FALSE if the window is unshaped or NULL.
   *  SDL_CreateShapedWindow
   *}
function SDL_IsShapedWindow(window: PSDL_Window): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_IsShapedWindow' {$ENDIF} {$ENDIF};

  {**
   *  The type used to identify a window
   *
   *   SDL_CreateWindow()
   *   SDL_CreateWindowFrom()
   *   SDL_DestroyWindow()
   *   SDL_GetWindowData()
   *   SDL_GetWindowFlags()
   *   SDL_GetWindowGrab()
   *   SDL_GetWindowPosition()
   *   SDL_GetWindowSize()
   *   SDL_GetWindowTitle()
   *   SDL_HideWindow()
   *   SDL_MaximizeWindow()
   *   SDL_MinimizeWindow()
   *   SDL_RaiseWindow()
   *   SDL_RestoreWindow()
   *   SDL_SetWindowData()
   *   SDL_SetWindowFullscreen()
   *   SDL_SetWindowGrab()
   *   SDL_SetWindowIcon()
   *   SDL_SetWindowPosition()
   *   SDL_SetWindowSize()
   *   SDL_SetWindowBordered()
   *   SDL_SetWindowTitle()
   *   SDL_ShowWindow()
   *}

const
  {**
   *  The flags on a window
   *
   *   SDL_GetWindowFlags()
   *}

  SDL_WINDOW_FULLSCREEN = $00000001;         {**< fullscreen window *}
  SDL_WINDOW_OPENGL = $00000002;             {**< window usable with OpenGL context *}
  SDL_WINDOW_SHOWN = $00000004;              {**< window is visible *}
  SDL_WINDOW_HIDDEN = $00000008;             {**< window is not visible *}
  SDL_WINDOW_BORDERLESS = $00000010;         {**< no window decoration *}
  SDL_WINDOW_RESIZABLE = $00000020;          {**< window can be resized *}
  SDL_WINDOW_MINIMIZED = $00000040;          {**< window is minimized *}
  SDL_WINDOW_MAXIMIZED = $00000080;          {**< window is maximized *}
  SDL_WINDOW_INPUT_GRABBED = $00000100;      {**< window has grabbed input focus *}
  SDL_WINDOW_INPUT_FOCUS = $00000200;        {**< window has input focus *}
  SDL_WINDOW_MOUSE_FOCUS = $00000400;        {**< window has mouse focus *}
  SDL_WINDOW_FULLSCREEN_DESKTOP = SDL_WINDOW_FULLSCREEN or $00001000;
  SDL_WINDOW_FOREIGN = $00000800;            {**< window not created by SDL *}
  SDL_WINDOW_ALLOW_HIGHDPI = $00002000;      {**< window should be created in high-DPI mode if supported *}

type
  TSDL_WindowFlags = DWord;

function SDL_WindowPos_IsUndefined(X: Variant): Variant;
function SDL_WindowPos_IsCentered(X: Variant): Variant;

const
   {**
   *  Used to indicate that you don't care what the window position is.
   *}

  SDL_WINDOWPOS_UNDEFINED_MASK = $1FFF0000;
  SDL_WINDOWPOS_UNDEFINED = SDL_WINDOWPOS_UNDEFINED_MASK or 0;


  {**
   *  Used to indicate that the window position should be centered.
   *}

  SDL_WINDOWPOS_CENTERED_MASK = $2FFF0000;
  SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED_MASK or 0;

  {**
   *  Event subtype for window events
   *}

  SDL_WINDOWEVENT_NONE = 0;           {**< Never used *}
  SDL_WINDOWEVENT_SHOWN = 1;          {**< Window has been shown *}
  SDL_WINDOWEVENT_HIDDEN = 2;         {**< Window has been hidden *}
  SDL_WINDOWEVENT_EXPOSED = 3;        {**< Window has been exposed and should be redrawn *}
  SDL_WINDOWEVENT_MOVED = 4;          {**< Window has been moved to data1; data2 *}
  SDL_WINDOWEVENT_RESIZED = 5;        {**< Window has been resized to data1xdata2 *}
  SDL_WINDOWEVENT_SIZE_CHANGED = 6;   {**< The window size has changed; either as a result of an API call or through the system or user changing the window size. *}
  SDL_WINDOWEVENT_MINIMIZED = 7;      {**< Window has been minimized *}
  SDL_WINDOWEVENT_MAXIMIZED = 8;      {**< Window has been maximized *}
  SDL_WINDOWEVENT_RESTORED = 9;       {**< Window has been restored to normal size and position *}
  SDL_WINDOWEVENT_ENTER = 10;          {**< Window has gained mouse focus *}
  SDL_WINDOWEVENT_LEAVE = 11;          {**< Window has lost mouse focus *}
  SDL_WINDOWEVENT_FOCUS_GAINED = 12;   {**< Window has gained keyboard focus *}
  SDL_WINDOWEVENT_FOCUS_LOST = 13;     {**< Window has lost keyboard focus *}
  SDL_WINDOWEVENT_CLOSE = 14;          {**< The window manager requests that the window be closed *}

type
  TSDL_WindowEventID = DWord;

  {**
   *  An opaque handle to an OpenGL context.
   *}

  TSDL_GLContext = Pointer;

  {**
   *  OpenGL configuration attributes
   *}

const
  SDL_GL_RED_SIZE = 0;
  SDL_GL_GREEN_SIZE = 1;
  SDL_GL_BLUE_SIZE = 2;
  SDL_GL_ALPHA_SIZE = 3;
  SDL_GL_BUFFER_SIZE = 4;
  SDL_GL_DOUBLEBUFFER = 5;
  SDL_GL_DEPTH_SIZE = 6;
  SDL_GL_STENCIL_SIZE = 7;
  SDL_GL_ACCUM_RED_SIZE = 8;
  SDL_GL_ACCUM_GREEN_SIZE = 9;
  SDL_GL_ACCUM_BLUE_SIZE = 10;
  SDL_GL_ACCUM_ALPHA_SIZE = 11;
  SDL_GL_STEREO = 12;
  SDL_GL_MULTISAMPLEBUFFERS = 13;
  SDL_GL_MULTISAMPLESAMPLES = 14;
  SDL_GL_ACCELERATED_VISUAL = 15;
  SDL_GL_RETAINED_BACKING = 16;
  SDL_GL_CONTEXT_MAJOR_VERSION = 17;
  SDL_GL_CONTEXT_MINOR_VERSION = 18;
  SDL_GL_CONTEXT_EGL = 19;
  SDL_GL_CONTEXT_FLAGS = 20;
  SDL_GL_CONTEXT_PROFILE_MASK = 21;
  SDL_GL_SHARE_WITH_CURRENT_CONTEXT = 22;
  SDL_GL_FRAMEBUFFER_SRGB_CAPABLE = 23;

type
  TSDL_GLattr = DWord;

const
  SDL_GL_CONTEXT_PROFILE_CORE           = $0001;
  SDL_GL_CONTEXT_PROFILE_COMPATIBILITY  = $0002;
  SDL_GL_CONTEXT_PROFILE_ES             = $0004;

type
  TSDL_GLprofile = DWord;

const
  SDL_GL_CONTEXT_DEBUG_FLAG              = $0001;
  SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG = $0002;
  SDL_GL_CONTEXT_ROBUST_ACCESS_FLAG      = $0004;
  SDL_GL_CONTEXT_RESET_ISOLATION_FLAG    = $0008;

type
  TSDL_GLcontextFlag = DWord;

  {* Function prototypes *}

  {**
   *  Get the number of video drivers compiled into SDL
   *
   *  SDL_GetVideoDriver()
   *}

function SDL_GetNumVideoDrivers: SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetNumVideoDrivers' {$ENDIF} {$ENDIF};

  {**
   *  Get the name of a built in video driver.
   *
   *  The video drivers are presented in the order in which they are
   *  normally checked during initialization.
   *
   *  SDL_GetNumVideoDrivers()
   *}

function SDL_GetVideoDriver(index: SInt32): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetVideoDriver' {$ENDIF} {$ENDIF};

  {**
   *  Initialize the video subsystem, optionally specifying a video driver.
   *
   *  driver_name Initialize a specific driver by name, or nil for the
   *  default video driver.
   *
   *  0 on success, -1 on error
   *
   *  This function initializes the video subsystem; setting up a connection
   *  to the window manager, etc, and determines the available display modes
   *  and pixel formats, but does not initialize a window or graphics mode.
   *
   *  SDL_VideoQuit()
   *}

function SDL_VideoInit(const driver_name: PAnsiChar): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_VideoInit' {$ENDIF} {$ENDIF};

  {**
   *  Shuts down the video subsystem.
   *
   *  function closes all windows, and restores the original video mode.
   *
   *  SDL_VideoInit()
   *}
procedure SDL_VideoQuit cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_VideoQuit' {$ENDIF} {$ENDIF};

  {**
   *  Returns the name of the currently initialized video driver.
   *
   *  The name of the current video driver or nil if no driver
   *  has been initialized
   *
   *  SDL_GetNumVideoDrivers()
   *  SDL_GetVideoDriver()
   *}

function SDL_GetCurrentVideoDriver: PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetCurrentVideoDriver' {$ENDIF} {$ENDIF};

  {**
   *  Returns the number of available video displays.
   *
   *  SDL_GetDisplayBounds()
   *}

function SDL_GetNumVideoDisplays: SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetNumVideoDisplays' {$ENDIF} {$ENDIF};

  {**
   *  Get the name of a display in UTF-8 encoding
   *
   *  The name of a display, or nil for an invalid display index.
   *
   *  SDL_GetNumVideoDisplays()
   *}

function SDL_GetDisplayName(displayIndex: SInt32): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetDisplayName' {$ENDIF} {$ENDIF};

  {**
   *  Get the desktop area represented by a display, with the primary
   *  display located at 0,0
   *
   *  0 on success, or -1 if the index is out of range.
   *
   *  SDL_GetNumVideoDisplays()
   *}

function SDL_GetDisplayBounds(displayIndex: SInt32; rect: PSDL_Rect): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetDisplayBounds' {$ENDIF} {$ENDIF};

  {**
   *  Returns the number of available display modes.
   *
   *  SDL_GetDisplayMode()
   *}

function SDL_GetNumDisplayModes(displayIndex: SInt32): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetNumDisplayModes' {$ENDIF} {$ENDIF};

  {**
   *  Get the dots/pixels-per-inch for a display.
   *}

function SDL_GetDisplayDPI(displayIndex: SInt32; ddpi, hdpi, vdpi: PFloat): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetDisplayDPI' {$ENDIF} {$ENDIF};

  {**
   *  Fill in information about a specific display mode.
   *
   *  The display modes are sorted in this priority:
   *        bits per pixel -> more colors to fewer colors
   *        width -> largest to smallest
   *        height -> largest to smallest
   *        refresh rate -> highest to lowest
   *
   *  SDL_GetNumDisplayModes()
   *}

function SDL_GetDisplayMode(displayIndex: SInt32; modeIndex: SInt32; mode: PSDL_DisplayMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetDisplayMode' {$ENDIF} {$ENDIF};

  {**
   *  Fill in information about the desktop display mode.
   *}

function SDL_GetDesktopDisplayMode(displayIndex: SInt32; mode: PSDL_DisplayMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetDesktopDisplayMode' {$ENDIF} {$ENDIF};

  {**
   *  Fill in information about the current display mode.
   *}

function SDL_GetCurrentDisplayMode(displayIndex: SInt32; mode: PSDL_DisplayMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetCurrentDisplayIndex' {$ENDIF} {$ENDIF};

  {**
   *  Get the closest match to the requested display mode.
   *
   *  mode The desired display mode
   *  closest A pointer to a display mode to be filled in with the closest
   *  match of the available display modes.
   *
   *  The passed in value closest, or nil if no matching video mode
   *  was available.
   *
   *  The available display modes are scanned, and closest is filled in with the
   *  closest mode matching the requested mode and returned.  The mode format and
   *  refresh_rate default to the desktop mode if they are 0.  The modes are
   *  scanned with size being first priority, format being second priority, and
   *  finally checking the refresh_rate.  If all the available modes are too
   *  small, then nil is returned.
   *
   *  SDL_GetNumDisplayModes()
   *  SDL_GetDisplayMode()
   *}

function SDL_GetClosestDisplayMode(displayIndex: SInt32; const mode: PSDL_DisplayMode; closest: PSDL_DisplayMode): PSDL_DisplayMode cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetClosestDisplayMode' {$ENDIF} {$ENDIF};

  {**
   *  Get the display index associated with a window.
   *
   *  the display index of the display containing the center of the
   *  window, or -1 on error.
   *}

function SDL_GetWindowDisplayIndex(window: PSDL_Window): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowDisplayIndex' {$ENDIF} {$ENDIF};

  {**
   *  Set the display mode used when a fullscreen window is visible.
   *
   *  By default the window's dimensions and the desktop format and refresh rate
   *  are used.
   *
   *  mode The mode to use, or nil for the default mode.
   *
   *  0 on success, or -1 if setting the display mode failed.
   *
   *  SDL_GetWindowDisplayMode()
   *  SDL_SetWindowFullscreen()
   *}

function SDL_SetWindowDisplayMode(window: PSDL_Window; const mode: PSDL_DisplayMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowDisplayMode' {$ENDIF} {$ENDIF};

  {**
   *  Fill in information about the display mode used when a fullscreen
   *  window is visible.
   *
   *  SDL_SetWindowDisplayMode()
   *  SDL_SetWindowFullscreen()
   *}

function SDL_GetWindowDisplayMode(window: PSDL_Window; mode: PSDL_DisplayMode): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowDisplayMode' {$ENDIF} {$ENDIF};

  {**
   *  Get the pixel format associated with the window.
   *}

function SDL_GetWindowPixelFormat(window: PSDL_Window): UInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowPixelFormat' {$ENDIF} {$ENDIF};

  {**
   *  Create a window with the specified position, dimensions, and flags.
   *
   *  title The title of the window, in UTF-8 encoding.
   *  x     The x position of the window, ::SDL_WINDOWPOS_CENTERED, or
   *               ::SDL_WINDOWPOS_UNDEFINED.
   *  y     The y position of the window, ::SDL_WINDOWPOS_CENTERED, or
   *               ::SDL_WINDOWPOS_UNDEFINED.
   *  w     The width of the window.
   *  h     The height of the window.
   *  flags The flags for the window, a mask of any of the following:
   *               ::SDL_WINDOW_FULLSCREEN, ::SDL_WINDOW_OPENGL,
   *               ::SDL_WINDOW_SHOWN,      ::SDL_WINDOW_BORDERLESS,
   *               ::SDL_WINDOW_RESIZABLE,  ::SDL_WINDOW_MAXIMIZED,
   *               ::SDL_WINDOW_MINIMIZED,  ::SDL_WINDOW_INPUT_GRABBED.
   *
   *  The id of the window created, or zero if window creation failed.
   *
   *  SDL_DestroyWindow()
   *}

function SDL_CreateWindow(const title: PAnsiChar; x: SInt32; y: SInt32; w: SInt32; h: SInt32; flags: UInt32): PSDL_Window cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateWindow' {$ENDIF} {$ENDIF};

  {**
   *  Create an SDL window from an existing native window.
   *
   *  data A pointer to driver-dependent window creation data
   *
   *  The id of the window created, or zero if window creation failed.
   *
   *  SDL_DestroyWindow()
   *}

function SDL_CreateWindowFrom(const data: Pointer): PSDL_Window cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_CreateWindowFrom' {$ENDIF} {$ENDIF};

  {**
   *  Get the numeric ID of a window, for logging purposes.
   *}

function SDL_GetWindowID(window: PSDL_Window): UInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowID' {$ENDIF} {$ENDIF};

  {**
   *  Get a window from a stored ID, or nil if it doesn't exist.
   *}

function SDL_GetWindowFromID(id: UInt32): PSDL_Window cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowFromID' {$ENDIF} {$ENDIF};

  {**
   *  Get the window flags.
   *}

function SDL_GetWindowFlags(window: PSDL_Window): UInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowFlags' {$ENDIF} {$ENDIF};

  {**
   *  Set the title of a window, in UTF-8 format.
   *
   *  SDL_GetWindowTitle()
   *}

procedure SDL_SetWindowTitle(window: PSDL_Window; const title: PAnsiChar) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowTitle' {$ENDIF} {$ENDIF};

  {**
   *  Get the title of a window, in UTF-8 format.
   *
   *  SDL_SetWindowTitle()
   *}

function SDL_GetWindowTitle(window: PSDL_Window): PAnsiChar cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowTitle' {$ENDIF} {$ENDIF};

  {**
   *  Set the icon for a window.
   *
   *  icon The icon for the window.
   *}

procedure SDL_SetWindowIcon(window: PSDL_Window; icon: PSDL_Surface) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowIcon' {$ENDIF} {$ENDIF};

  {**
   *  Associate an arbitrary named pointer with a window.
   *
   *  window   The window to associate with the pointer.
   *  name     The name of the pointer.
   *  userdata The associated pointer.
   *
   *  The previous value associated with 'name'
   *
   *  The name is case-sensitive.
   *
   *  SDL_GetWindowData()
   *}

function SDL_SetWindowData(window: PSDL_Window; const name: PAnsiChar; userdata: Pointer): Pointer cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowData' {$ENDIF} {$ENDIF};

  {**
   *  Retrieve the data pointer associated with a window.
   *
   *  window   The window to query.
   *  name     The name of the pointer.
   *
   *  The value associated with 'name'
   *
   *  SDL_SetWindowData()
   *}

function SDL_GetWindowData(window: PSDL_Window; const name: PAnsiChar): Pointer cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowData' {$ENDIF} {$ENDIF};

  {**
   *  Set the position of a window.
   *
   *  window   The window to reposition.
   *  x        The x coordinate of the window, SDL_WINDOWPOS_CENTERED, or
   *                  SDL_WINDOWPOS_UNDEFINED.
   *  y        The y coordinate of the window, SDL_WINDOWPOS_CENTERED, or
   *                  SDL_WINDOWPOS_UNDEFINED.
   *
   *  The window coordinate origin is the upper left of the display.
   *
   *  SDL_GetWindowPosition()
   *}

procedure SDL_SetWindowPosition(window: PSDL_Window; x: SInt32; y: SInt32) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowPosition' {$ENDIF} {$ENDIF};

  {**
   *  Get the position of a window.
   *
   *  x        Pointer to variable for storing the x position, may be nil
   *  y        Pointer to variable for storing the y position, may be nil
   *
   *  SDL_SetWindowPosition()
   *}

procedure SDL_GetWindowPosition(window: PSDL_Window; x: PInt; y: PInt) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowPosition' {$ENDIF} {$ENDIF};

  {**
   *  Set the size of a window's client area.
   *
   *  w        The width of the window, must be >0
   *  h        The height of the window, must be >0
   *
   *  You can't change the size of a fullscreen window, it automatically
   *  matches the size of the display mode.
   *
   *  SDL_GetWindowSize()
   *}

procedure SDL_SetWindowSize(window: PSDL_Window; w: SInt32; h: SInt32) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowSize' {$ENDIF} {$ENDIF};

  {**
   *  Get the size of a window's client area.
   *
   *  w        Pointer to variable for storing the width, may be nil
   *  h        Pointer to variable for storing the height, may be nil
   *
   *  SDL_SetWindowSize()
   *}

procedure SDL_GetWindowSize(window: PSDL_Window; w: PInt; h: PInt) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowSize' {$ENDIF} {$ENDIF};

  {**
   *  Set the minimum size of a window's client area.
   *
   *  min_w     The minimum width of the window, must be >0
   *  min_h     The minimum height of the window, must be >0
   *
   *  You can't change the minimum size of a fullscreen window, it
   *  automatically matches the size of the display mode.
   *
   *  SDL_GetWindowMinimumSize()
   *  SDL_SetWindowMaximumSize()
   *}

procedure SDL_SetWindowMinimumSize(window: PSDL_Window; min_w: SInt32; min_h: SInt32) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowMinimumSize' {$ENDIF} {$ENDIF};

  {**
   *  Get the minimum size of a window's client area.
   *
   *  w        Pointer to variable for storing the minimum width, may be nil
   *  h        Pointer to variable for storing the minimum height, may be nil
   *
   *  SDL_GetWindowMaximumSize()
   *  SDL_SetWindowMinimumSize()
   *}

procedure SDL_GetWindowMinimumSize(window: PSDL_Window; w: PInt; h: PInt) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowMinimumSize' {$ENDIF} {$ENDIF};

  {**
   *  Set the maximum size of a window's client area.
   *
   *  max_w     The maximum width of the window, must be >0
   *  max_h     The maximum height of the window, must be >0
   *
   *  You can't change the maximum size of a fullscreen window, it
   *  automatically matches the size of the display mode.
   *
   *  SDL_GetWindowMaximumSize()
   *  SDL_SetWindowMinimumSize()
   *}

procedure SDL_SetWindowMaximumSize(window: PSDL_Window; max_w: SInt32; max_h: SInt32) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowMaximumSize' {$ENDIF} {$ENDIF};

  {**
   *  Get the maximum size of a window's client area.
   *
   *  w        Pointer to variable for storing the maximum width, may be nil
   *  h        Pointer to variable for storing the maximum height, may be nil
   *
   *  SDL_GetWindowMinimumSize()
   *  SDL_SetWindowMaximumSize()
   *}

procedure SDL_GetWindowMaximumSize(window: PSDL_Window; w: PInt; h: PInt) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowMaximumSize' {$ENDIF} {$ENDIF};

  {**
   *  Set the border state of a window.
   *
   *  This will add or remove the window's SDL_WINDOW_BORDERLESS flag and
   *  add or remove the border from the actual window. This is a no-op if the
   *  window's border already matches the requested state.
   *
   *  window The window of which to change the border state.
   *  bordered SDL_FALSE to remove border, SDL_TRUE to add border.
   *
   *  You can't change the border state of a fullscreen window.
   *
   *  SDL_GetWindowFlags()
   *}

procedure SDL_SetWindowBordered(window: PSDL_Window; bordered: TSDL_Bool) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowBordered' {$ENDIF} {$ENDIF};

  {**
   *  Show a window.
   *
   *  SDL_HideWindow()
   *}

procedure SDL_ShowWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_ShowWindow' {$ENDIF} {$ENDIF};

  {**
   *  Hide a window.
   *
   *  SDL_ShowWindow()
   *}

procedure SDL_HideWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HideWindow' {$ENDIF} {$ENDIF};

  {**
   *  Raise a window above other windows and set the input focus.
   *}

procedure SDL_RaiseWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RaiseWindow' {$ENDIF} {$ENDIF};

  {**
   *  Make a window as large as possible.
   *
   *  SDL_RestoreWindow()
   *}

procedure SDL_MaximizeWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_MaximizeWindow' {$ENDIF} {$ENDIF};

  {**
   *  Minimize a window to an iconic representation.
   *
   *  SDL_RestoreWindow()
   *}

procedure SDL_MinimizeWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_MinimizeWindow' {$ENDIF} {$ENDIF};

  {**
   *  Restore the size and position of a minimized or maximized window.
   *
   *  SDL_MaximizeWindow()
   *  SDL_MinimizeWindow()
   *}

procedure SDL_RestoreWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RestoreWindow' {$ENDIF} {$ENDIF};

  {**
   *  Set a window's fullscreen state.
   *
   *  0 on success, or -1 if setting the display mode failed.
   *
   *  SDL_SetWindowDisplayMode()
   *  SDL_GetWindowDisplayMode()
   *}

function SDL_SetWindowFullscreen(window: PSDL_Window; flags: UInt32): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowFullscreen' {$ENDIF} {$ENDIF};

  {**
   *  Get the SDL surface associated with the window.
   *
   *  The window's framebuffer surface, or nil on error.
   *
   *  A new surface will be created with the optimal format for the window,
   *  if necessary. This surface will be freed when the window is destroyed.
   *
   *  You may not combine this with 3D or the rendering API on this window.
   *
   *  SDL_UpdateWindowSurface()
   *  SDL_UpdateWindowSurfaceRects()
   *}

function SDL_GetWindowSurface(window: PSDL_Window): PSDL_Surface cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowSurface' {$ENDIF} {$ENDIF};

  {**
   *  Copy the window surface to the screen.
   *
   *  0 on success, or -1 on error.
   *
   *  SDL_GetWindowSurface()
   *  SDL_UpdateWindowSurfaceRects()
   *}

function SDL_UpdateWindowSurface(window: PSDL_Window): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_UpdateWindowSurface' {$ENDIF} {$ENDIF};

  {**
   *  Copy a number of rectangles on the window surface to the screen.
   *
   *  0 on success, or -1 on error.
   *
   *  SDL_GetWindowSurface()
   *  SDL_UpdateWindowSurfaceRect()
   *}

function SDL_UpdateWindowSurfaceRects(window: PSDL_Window; rects: PSDL_Rect; numrects: SInt32): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_UpdateWindowSurfaceRects' {$ENDIF} {$ENDIF};

  {**
   *  Set a window's input grab mode.
   *
   *  grabbed This is SDL_TRUE to grab input, and SDL_FALSE to release input.
   *
   *  SDL_GetWindowGrab()
   *}

procedure SDL_SetWindowGrab(window: PSDL_Window; grabbed: TSDL_Bool) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowGrab' {$ENDIF} {$ENDIF};

  {**
   *  Get a window's input grab mode.
   *
   *  This returns SDL_TRUE if input is grabbed, and SDL_FALSE otherwise.
   *
   *  SDL_SetWindowGrab()
   *}

function SDL_GetWindowGrab(window: PSDL_Window): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowGrab' {$ENDIF} {$ENDIF};

  {**
   *  Set the brightness (gamma correction) for a window.
   *
   *  0 on success, or -1 if setting the brightness isn't supported.
   *
   *  SDL_GetWindowBrightness()
   *  SDL_SetWindowGammaRamp()
   *}

function SDL_SetWindowBrightness(window: PSDL_Window; brightness: Float): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowBrightness' {$ENDIF} {$ENDIF};

  {**
   *  Get the brightness (gamma correction) for a window.
   *
   *  The last brightness value passed to SDL_SetWindowBrightness()
   *
   *  SDL_SetWindowBrightness()
   *}

function SDL_GetWindowBrightness(window: PSDL_Window): Float cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowBrightness' {$ENDIF} {$ENDIF};

  {**
   *  Set the gamma ramp for a window.
   *
   *  red The translation table for the red channel, or nil.
   *  green The translation table for the green channel, or nil.
   *  blue The translation table for the blue channel, or nil.
   *
   *  0 on success, or -1 if gamma ramps are unsupported.
   *
   *  Set the gamma translation table for the red, green, and blue channels
   *  of the video hardware.  Each table is an array of 256 16-bit quantities,
   *  representing a mapping between the input and output for that channel.
   *  The input is the index into the array, and the output is the 16-bit
   *  gamma value at that index, scaled to the output color precision.
   *
   *  SDL_GetWindowGammaRamp()
   *}

function SDL_SetWindowGammaRamp(window: PSDL_Window; const red: PUInt16; const green: PUInt16; const blue: PUInt16): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetWindowGammaRamp' {$ENDIF} {$ENDIF};

  {**
   *  Get the gamma ramp for a window.
   *
   *  red   A pointer to a 256 element array of 16-bit quantities to hold
   *        the translation table for the red channel, or nil.
   *  green A pointer to a 256 element array of 16-bit quantities to hold
   *        the translation table for the green channel, or nil.
   *  blue  A pointer to a 256 element array of 16-bit quantities to hold
   *        the translation table for the blue channel, or nil.
   *
   *  0 on success, or -1 if gamma ramps are unsupported.
   *
   *  SDL_SetWindowGammaRamp()
   *}

function SDL_GetWindowGammaRamp(window: PSDL_Window; red: PUInt16; green: PUInt16; blue: PUInt16): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetWindowGammaRamp' {$ENDIF} {$ENDIF};

  {**
   *  Destroy a window.
   *}

procedure SDL_DestroyWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DestroyWindow' {$ENDIF} {$ENDIF};

  {**
   *  Returns whether the screensaver is currently enabled (default on).
   *
   *  SDL_EnableScreenSaver()
   *  SDL_DisableScreenSaver()
   *}

function SDL_IsScreenSaverEnabled: TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_IsScreenSaverEnabled' {$ENDIF} {$ENDIF};

  {**
   *  Allow the screen to be blanked by a screensaver
   *
   *  SDL_IsScreenSaverEnabled()
   *  SDL_DisableScreenSaver()
   *}

procedure SDL_EnableScreenSaver cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_EnableScreenSaver' {$ENDIF} {$ENDIF};

  {**
   *  Prevent the screen from being blanked by a screensaver
   *
   *  SDL_IsScreenSaverEnabled()
   *  SDL_EnableScreenSaver()
   *}

procedure SDL_DisableScreenSaver cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DisableScreenSaver' {$ENDIF} {$ENDIF};

  {**
   *  OpenGL support functions
   *}

  {**
   *  Dynamically load an OpenGL library.
   *
   *  path The platform dependent OpenGL library name, or nil to open the
   *              default OpenGL library.
   *
   *  0 on success, or -1 if the library couldn't be loaded.
   *
   *  This should be done after initializing the video driver, but before
   *  creating any OpenGL windows.  If no OpenGL library is loaded, the default
   *  library will be loaded upon creation of the first OpenGL window.
   *
   *  If you do this, you need to retrieve all of the GL functions used in
   *  your program from the dynamic library using SDL_GL_GetProcAddress().
   *
   *  SDL_GL_GetProcAddress()
   *  SDL_GL_UnloadLibrary()
   *}

function SDL_GL_LoadLibrary(const path: PAnsiChar): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_LoadLibrary' {$ENDIF} {$ENDIF};

  {**
   *  Get the address of an OpenGL function.
   *}

function SDL_GL_GetProcAddress(const proc: PAnsiChar): Pointer cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_GetProcAddress' {$ENDIF} {$ENDIF};

  {**
   *  Unload the OpenGL library previously loaded by SDL_GL_LoadLibrary().
   *
   *  SDL_GL_LoadLibrary()
   *}

procedure SDL_GL_UnloadLibrary cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_UnloadLibrary' {$ENDIF} {$ENDIF};

  {**
   *  Return true if an OpenGL extension is supported for the current
   *  context.
   *}

function SDL_GL_ExtensionSupported(const extension: PAnsiChar): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_ExtensionSupported' {$ENDIF} {$ENDIF};

  {**
   *  Reset all previously set OpenGL context attributes to their default values
   *}
procedure SDL_GL_ResetAttributes(); cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_ResetAttributes' {$ENDIF} {$ENDIF};

  {**
   *  Set an OpenGL window attribute before window creation.
   *}

function SDL_GL_SetAttribute(attr: TSDL_GLattr; value: SInt32): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_SetAttribute' {$ENDIF} {$ENDIF};

  {**
   *  Get the actual value for an attribute from the current context.
   *}

function SDL_GL_GetAttribute(attr: TSDL_GLattr; value: PInt): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_GetAttribute' {$ENDIF} {$ENDIF};

  {**
   *  Create an OpenGL context for use with an OpenGL window, and make it
   *  current.
   *
   *  SDL_GL_DeleteContext()
   *}

function SDL_GL_CreateContext(window: PSDL_Window): TSDL_GLContext cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_CreateContext' {$ENDIF} {$ENDIF};

  {**
   *  Set up an OpenGL context for rendering into an OpenGL window.
   *
   *  The context must have been created with a compatible window.
   *}

function SDL_GL_MakeCurrent(window: PSDL_Window; context: TSDL_GLContext): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_MakeCurrent' {$ENDIF} {$ENDIF};

  {**
   *  Get the currently active OpenGL window.
   *}
function SDL_GL_GetCurrentWindow: PSDL_Window cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_GetCurrentWindow' {$ENDIF} {$ENDIF};

  {**
   *  Get the currently active OpenGL context.
   *}
function SDL_GL_GetCurrentContext: TSDL_GLContext cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_GetCurrentContext' {$ENDIF} {$ENDIF};

  {**
   *  Set the swap interval for the current OpenGL context.
   *
   *  interval 0 for immediate updates, 1 for updates synchronized with the
   *  vertical retrace. If the system supports it, you may
   *  specify -1 to allow late swaps to happen immediately
   *  instead of waiting for the next retrace.
   *
   *  0 on success, or -1 if setting the swap interval is not supported.
   *
   *  SDL_GL_GetSwapInterval()
   *}

function SDL_GL_SetSwapInterval(interval: SInt32): SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_SetSwapInterval' {$ENDIF} {$ENDIF};

  {**
   *  Get the swap interval for the current OpenGL context.
   *
   *  0 if there is no vertical retrace synchronization, 1 if the buffer
   *  swap is synchronized with the vertical retrace, and -1 if late
   *  swaps happen immediately instead of waiting for the next retrace.
   *  If the system can't determine the swap interval, or there isn't a
   *  valid current context, this will return 0 as a safe default.
   *
   *  SDL_GL_SetSwapInterval()
   *}

function SDL_GL_GetSwapInterval: SInt32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_GetSwapInterval' {$ENDIF} {$ENDIF};

  {**
   *  Swap the OpenGL buffers for a window, if double-buffering is
   *  supported.
   *}

procedure SDL_GL_SwapWindow(window: PSDL_Window) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_SwapWindow' {$ENDIF} {$ENDIF};

  {**
   *  Delete an OpenGL context.
   *
   *  SDL_GL_CreateContext()
   *}

procedure SDL_GL_DeleteContext(context: TSDL_GLContext) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GL_DeleteContext' {$ENDIF} {$ENDIF};

  {*OpenGL support functions*}
