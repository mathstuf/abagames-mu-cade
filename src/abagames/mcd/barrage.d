/*
 * $Id: barrage.d,v 1.3 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.barrage;

private import std.math;
private import std.string;
private import std.path;
private import std.file;
private import bulletml;
private import abagames.util.logger;
private import abagames.mcd.bullet;
private import abagames.mcd.bulletpool;
private import abagames.mcd.bulletimpl;
private import abagames.mcd.bullettarget;

/**
 * Barrage pattern.
 */
public class Barrage {
 private:
  ParserParam[] parserParam;
  int prevWait, postWait;

  public void setWait(int prevWait, int postWait) {
    this.prevWait = prevWait;
    this.postWait = postWait;
  }

  public void addBml(BulletMLParser *p, float rank, float speed) {
    parserParam ~= new ParserParam(p, rank, speed);
  }

  public void addBml(char[] bmlDirName, char[] bmlFileName, float rank, float speed) {
    BulletMLParser *p = BarrageManager.getInstance(bmlDirName, bmlFileName);
    if (!p)
      throw new Error("File not found: " ~ bmlDirName ~ "/" ~ bmlFileName);
    addBml(p, rank, speed);
  }

  public BulletActor addTopBullet(BulletPool bullets, BulletTarget target, float xReverse = 1) {
    return bullets.addTopBullet(parserParam,
                                0, 0, PI, 0,
                                xReverse, 1, target,
                                prevWait, postWait);
  }

  public void clear() {
    parserParam = null;
  }
}

/**
 * Barrage manager (BulletMLs' loader).
 */
public class BarrageManager {
 private:
  static BulletMLParserTinyXML *parser[char[]][char[]];
  static const char[] BARRAGE_DIR_NAME = "barrage";

  public static void load() {
    char[][] dirs = listdir(BARRAGE_DIR_NAME);
    foreach (char[] dirName; dirs) {
      char[][] files = listdir(BARRAGE_DIR_NAME ~ "/" ~ dirName);
      foreach (char[] fileName; files) {
        if (getExt(fileName) != "xml")
          continue;
        parser[dirName][fileName] = loadInstance(dirName, fileName);
      }
    }
  }

  private static BulletMLParserTinyXML* loadInstance(char[] dirName, char[] fileName) {
    char[] barrageName = dirName ~ "/" ~ fileName;
    Logger.info("Load BulletML: " ~ barrageName);
    parser[dirName][fileName] =
      BulletMLParserTinyXML_new(std.string.toStringz(BARRAGE_DIR_NAME ~ "/" ~ barrageName));
    BulletMLParserTinyXML_parse(parser[dirName][fileName]);
    return parser[dirName][fileName];
  }

  public static BulletMLParserTinyXML* getInstance(char[] dirName, char[] fileName) {
    return parser[dirName][fileName];
  }

  public static BulletMLParserTinyXML*[] getInstanceList(char[] dirName) {
    BulletMLParserTinyXML *pl[];
    foreach (BulletMLParserTinyXML *p; parser[dirName]) {
      pl ~= p;
    }
    return pl;
  }

  public static void unload() {
    foreach (BulletMLParserTinyXML *pa[char[]]; parser) {
      foreach (BulletMLParserTinyXML *p; pa) {
        BulletMLParserTinyXML_delete(p);
      }
    }
  }
}
