/*
 * $Id: prefmanager.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.prefmanager;

private import std.stream;
private import abagames.util.prefmanager;

/**
 * Handle a high score table.
 */
public class PrefManager: abagames.util.prefmanager.PrefManager {
 private:
  static const int VERSION_NUM = 10;
  static const char[] PREF_FILE_NAME = "mcd.prf";
  PrefData _prefData;

  public this() {
    _prefData = new PrefData;
  }

  public void load() {
    auto File fd = new File;
    try {
      int ver;
      fd.open(PREF_FILE_NAME);
      fd.read(ver);
      if (ver != VERSION_NUM)
        throw new Error("Wrong version num");
      else
        _prefData.load(fd);
    } catch (Object e) {
      _prefData.init();
    } finally {
      if (fd.isOpen())
        fd.close();
    }
  }

  public void save() {
    auto File fd = new File;
    fd.create(PREF_FILE_NAME);
    fd.write(VERSION_NUM);
    _prefData.save(fd);
    fd.close();
  }

  public PrefData prefData() {
    return _prefData;
  }
}

public class PrefData {
 public:
  static const int RANKING_NUM = 10;
 private:
  int[RANKING_NUM] _highScore;
  int[RANKING_NUM] _time;

  public void init() {
    for(int i = 0; i < RANKING_NUM; i++) {
      _highScore[i] = (10 - i) * 10000;
      _time[i] = (10 - i) * 10000;
    }
  }

  public void load(File fd) {
    for(int i = 0; i < RANKING_NUM; i++) {
      fd.read(_highScore[i]);
      fd.read(_time[i]);
    }
  }

  public void save(File fd) {
    for(int i = 0; i < RANKING_NUM; i++) {
      fd.write(_highScore[i]);
      fd.write(_time[i]);
    }
  }

  public void recordResult(int score, int t) {
    for(int i = 0; i < RANKING_NUM; i++) {
      if (score > _highScore[i]) {
        for (int j = RANKING_NUM - 1; j >= i + 1; j--) {
          _highScore[j] = _highScore[j - 1];
          _time[j] = _time[j - 1];
        }
        _highScore[i] = score;
        _time[i] = t;
        return;
      }
    }
  }

  public int[] highScore() {
    return _highScore;
  }

  public int[] time() {
    return _time;
  }
}
