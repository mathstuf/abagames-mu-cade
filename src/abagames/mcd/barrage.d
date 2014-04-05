/*
 * $Id: barrage.d,v 1.3 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.barrage;

private import std.algorithm;
private import std.math;
private import std.string;
private import std.path;
private import std.file;
private import bml = bulletml.bulletml;
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

  public void addBml(bml.ResolvedBulletML p, float rank, float speed) {
    parserParam ~= new ParserParam(p, rank, speed);
  }

  public void addBml(string bmlDirName, string bmlFileName, float rank, float speed) {
    bml.ResolvedBulletML p = BarrageManager.getInstance(bmlDirName, bmlFileName);
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
  static bml.ResolvedBulletML parser[string][string];
  static const string BARRAGE_DIR_NAME = "barrage";

  public static void load() {
    foreach (string dirPath; dirEntries(BARRAGE_DIR_NAME, SpanMode.shallow)) {
      if (!isDir(dirPath)) {
        continue;
      }
      string dirName = baseName(dirPath);
      foreach (string filePath; dirEntries(dirPath, "*.xml", SpanMode.shallow)) {
        string fileName = baseName(filePath);
        parser[dirName][fileName] = loadInstance(dirName, fileName);
      }
    }
  }

  private static bml.ResolvedBulletML loadInstance(string dirName, string fileName) {
    string barrageName = dirName ~ "/" ~ fileName;
    Logger.info("Load BulletML: " ~ barrageName);
    parser[dirName][fileName] = bml.resolve(bml.parse(BARRAGE_DIR_NAME ~ "/" ~ barrageName));
    return parser[dirName][fileName];
  }

  public static bml.ResolvedBulletML getInstance(string dirName, string fileName) {
    return parser[dirName][fileName];
  }

  public static bml.ResolvedBulletML[] getInstanceList(string dirName) {
    bml.ResolvedBulletML pl[];
    foreach (bml.ResolvedBulletML p; parser[dirName]) {
      pl ~= p;
    }
    return pl;
  }
}
