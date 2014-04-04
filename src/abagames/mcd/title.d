/*
 * $Id: title.d,v 1.2 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.title;

private import std.string;
private import opengl;
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

  public void draw() {
    glEnable(GL_TEXTURE_2D);
    float x = 250, y = 50;
    float lsz = 50, lof = 40;
    for (int i = 0; i < 5; i++) {
      glBlendFunc(GL_DST_COLOR,GL_ZERO);
      Screen.setColorForced(1, 1, 1);
      field.titleTexture.bindMask(i);
      field.drawLetter(i, x, y, lsz);
      glBlendFunc(GL_ONE, GL_ONE);
      Screen.setColor(1, 1, 1);
      field.titleTexture.bind(i);
      field.drawLetter(i, x, y, lsz);
      if (i == 0)
        x += lof * 1.0f;
      else
        x += lof * 0.9f;
    }
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glDisable(GL_TEXTURE_2D);
    if ((cnt % 120) < 60)
      Letter.drawString("PUSH SHOT BUTTON TO START", 200, 430, 5);
    if ((cnt % 3600) == 0)
      stageManager.initRank();
    drawRanking();
  }

  private void drawRanking() {
    int rn = (cnt - 60) / 40;
    if (rn > PrefData.RANKING_NUM)
      rn = PrefData.RANKING_NUM;
    float y = 120;
    for (int i = 0; i < rn; i++) {
      char[] rstr;
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
        rstr = std.string.toString(i + 1) ~ "TH";
        break;
      }
      if (i < 9)
        Letter.drawString(rstr, 80, y, 7);
      else
        Letter.drawString(rstr, 66, y, 7);
      Letter.drawNum(prefManager.prefData.highScore[i], 400, y, 6);
      Letter.drawTime(prefManager.prefData.time[i], 600, y + 6, 6);
      y += 24;
    }
  }
}
