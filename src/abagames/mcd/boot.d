/*
 * $Id: boot.d,v 1.3 2006/03/18 03:36:00 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.boot;

private import std.string;
private import std.stream;
private import std.math;
private import std.c.stdlib;
private import abagames.util.logger;
private import abagames.util.tokenizer;
private import abagames.util.sdl.mainloop;
private import abagames.util.sdl.input;
private import abagames.util.sdl.twinstickpad;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.sound;
private import abagames.mcd.screen;
private import abagames.mcd.gamemanager;
private import abagames.mcd.prefmanager;

/**
 * Boot the game.
 */
private:
Screen screen;
RecordableTwinStickPad input;
GameManager gameManager;
PrefManager prefManager;
MainLoop mainLoop;

version (Win32_release) {
  // Boot as the Windows executable.
  private import std.c.windows.windows;
  private import std.string;

  extern (C) void gc_init();
  extern (C) void gc_term();
  extern (C) void _minit();
  extern (C) void _moduleCtor();

  extern (Windows)
  public int WinMain(HINSTANCE hInstance,
		     HINSTANCE hPrevInstance,
		     LPSTR lpCmdLine,
		     int nCmdShow) {
    int result;
    gc_init();
    _minit();
    try {
      _moduleCtor();
      char exe[4096];
      GetModuleFileNameA(null, exe, 4096);
      char[][1] prog;
      prog[0] = std.string.toString(exe);
      result = boot(prog ~ std.string.split(std.string.toString(lpCmdLine)));
    } catch (Object o) {
      Logger.error("Exception: " ~ o.toString());
      result = EXIT_FAILURE;
    }
    gc_term();
    return result;
  }
} else {
  // Boot as the general executable.
  public int main(char[][] args) {
    return boot(args);
  }
}

public int boot(char[][] args) {
  screen = new Screen;
  input = new RecordableTwinStickPad;
  gameManager = new GameManager;
  prefManager = new PrefManager;
  mainLoop = new MainLoop(screen, input, gameManager, prefManager);
  try {
    parseArgs(args, screen);
  } catch (Exception e) {
    return EXIT_FAILURE;
  }
  mainLoop.loop();
  return EXIT_SUCCESS;
}

private void parseArgs(char[][] commandArgs, Screen screen) {
  char[][] args = readOptionsIniFile();
  for (int i = 1; i < commandArgs.length; i++)
    args ~= commandArgs[i];
  char[] progName = commandArgs[0];
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
    case "-brightness":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      float b = cast(float) std.string.atoi(args[i]) / 100;
      if (b < 0 || b > 1) {
        usage(args[0]);
        throw new Exception("Invalid options");
      }
      Screen.brightness = b;
      break;
    case "-window":
      screen.windowMode = true;
      break;
    case "-res":
      if (i >= args.length - 2) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      int w = std.string.atoi(args[i]);
      i++;
      int h = std.string.atoi(args[i]);
      screen.width = w;
      screen.height = h;
      break;
    case "-nosound":
      SoundManager.noSound = true;
      break;
    case "-exchange":
      TwinStickPad.buttonReversed = true;
      break;
    case "-rotatestick2":
    case "-rotaterightstick":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      TwinStickPad.rotate = cast(float) std.string.atoi(args[i]) * PI / 180.0f;
      break;
    case "-reversestick2":
    case "-reverserightstick":
      TwinStickPad.reverse = -1;
      break;
    case "-disablestick2":
      TwinStickPad.disableStick2 = true;
      break;
    case "-enableaxis5":
      TwinStickPad.enableAxis5 = true;
      break;
    case "-accframe":
      mainLoop.accframe = 1;
      break;
    default:
      usage(progName);
      throw new Exception("Invalid options");
    }
  }
}

private final const char[] OPTIONS_INI_FILE = "options.ini";

private char[][] readOptionsIniFile() {
  try {
    return Tokenizer.readFile(OPTIONS_INI_FILE, " ");
  } catch (Object e) {
    return null;
  }
}

private void usage(char[] progName) {
  Logger.error
    ("Usage: " ~ progName ~ " [-window] [-res x y] [-brightness [0-100]] [-nosound] [-exchange] [-rotatestick2 deg] [-reversestick2] [-disablestick2] [-enableaxis5]");
}
