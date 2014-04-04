/*
 * $Id: replay.d,v 1.2 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.replay;

private import std.stream;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.twinstickpad;
private import abagames.mcd.gamemanager;

/**
 * Save/Load a replay data.
 */
public class ReplayData {
 public:
  static const char[] dir = "replay";
  static const int VERSION_NUM = 10;
  InputRecord!(TwinStickPadState) twinStickPadInputRecord;
  long seed;
  int score = 0;
  int time = 0;
 private:

  public void save(char[] fileName) {
    auto File fd = new File;
    fd.create(dir ~ "/" ~ fileName);
    fd.write(VERSION_NUM);
    fd.write(seed);
    fd.write(score);
    fd.write(time);
    twinStickPadInputRecord.save(fd);
    fd.close();
  }

  public void load(char[] fileName) {
    auto File fd = new File;
    fd.open(dir ~ "/" ~ fileName);
    int ver;
    fd.read(ver);
    if (ver != VERSION_NUM)
      throw new Error("Wrong version num");
    fd.read(seed);
    fd.read(score);
    fd.read(time);
    twinStickPadInputRecord = new InputRecord!(TwinStickPadState);
    twinStickPadInputRecord.load(fd);
    fd.close();
  }
}
