/*
 * $Id: logger.d,v 1.2 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.logger;

private import std.conv;
private import std.cstream;
private import std.string;

/**
 * Logger(error/info).
 */
version(Windows) {

private import std.string;
private import std.c.windows.windows;

public class Logger {

  public static void info(string msg, bool nline = true) {
    // Win32 exe crashes if it writes something to stderr.
    /*if (nline)
      std.cstream.derr.writeLine(msg);
    else
      std.cstream.derr.writeString(msg);*/
  }

  public static void info(double n, bool nline = true) {
    /*if (nline)
      std.cstream.derr.writeLine(std.string.toString(n));
    else
      std.cstream.derr.writeString(std.string.toString(n) ~ " ");*/
  }

  private static void putMessage(string msg) {
    MessageBoxA(null, std.string.toStringz(msg), "Error", MB_OK | MB_ICONEXCLAMATION);
  }

  public static void error(string msg) {
    putMessage("Error: " ~ msg);
  }

  public static void error(Exception e) {
    putMessage("Error: " ~ e.toString());
  }

  public static void error(Error e) {
    putMessage("Error: " ~ e.toString());
  }
}

} else {

public class Logger {

  public static void info(string msg, bool nline = true) {
    if (nline)
      std.cstream.derr.writeLine(msg);
    else
      std.cstream.derr.writeString(msg);
  }

  public static void info(double n, bool nline = true) {
    if (nline)
      std.cstream.derr.writeLine(to!string(n));
    else
      std.cstream.derr.writeString(to!string(n) ~ " ");
  }

  public static void error(string msg) {
    std.cstream.derr.writeLine("Error: " ~ msg);
  }

  public static void error(Exception e) {
    std.cstream.derr.writeLine("Error: " ~ e.toString());
  }

  public static void error(Error e) {
    std.cstream.derr.writeLine("Error: " ~ e.toString());
    if (e.next)
      error(to!Exception(e.next));
  }
}

}
