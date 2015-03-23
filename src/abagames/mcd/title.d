/*
 * $Id: title.d,v 1.2 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.title;

private import std.conv;
private import std.string;
private import gl3n.linalg;
private import abagames.util.support.gl;
private import abagames.mcd.screen;
private import abagames.mcd.field;
private import abagames.mcd.letter;
private import abagames.mcd.stagemanager;
private import abagames.mcd.prefmanager;

/**
 * Title screen.
 */
public class TitleManager {
 private:
  Field field;
  StageManager stageManager;
  PrefManager prefManager;
  int cnt;

  public this(Field field, StageManager stageManager, PrefManager prefManager) {
    this.field = field;
    this.stageManager = stageManager;
    this.prefManager = prefManager;
  }

  public void start() {
    cnt = 0;
  }

  public void move() {
    cnt++;
  }

  public void draw(mat4 view) {
    float x = 250, y = 50;
    float lsz = 50, lof = 40;

    field.drawLogo(view, x, y, lsz, lof, false);

    if ((cnt % 120) < 60)
      Letter.drawString(view, "PUSH SHOT BUTTON TO START", 200, 430, 5);
    if ((cnt % 3600) == 0)
      stageManager.initRank();
    drawRanking(view);
  }

  private void drawRanking(mat4 view) {
    int rn = (cnt - 60) / 40;
    if (rn > PrefData.RANKING_NUM)
      rn = PrefData.RANKING_NUM;
    float y = 120;
    for (int i = 0; i < rn; i++) {
      string rstr;
      switch (i) {
      case 0:
        rstr = "1ST";
        break;
      case 1:
        rstr = "2ND";
        break;
      case 2:
        rstr = "3RD";
        break;
      default:
        rstr = to!string(i + 1) ~ "TH";
        break;
      }
      if (i < 9)
        Letter.drawString(view, rstr, 80, y, 7);
      else
        Letter.drawString(view, rstr, 66, y, 7);
      Letter.drawNum(view, prefManager.prefData.highScore[i], 400, y, 6);
      Letter.drawTime(view, prefManager.prefData.time[i], 600, y + 6, 6);
      y += 24;
    }
  }
}
