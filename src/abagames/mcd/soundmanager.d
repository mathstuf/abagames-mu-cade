/*
 * $Id: soundmanager.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.soundmanager;

private import std.path;
private import std.file;
private import abagames.util.rand;
private import abagames.util.logger;
private import abagames.util.sdl.sound;

/**
 * Manage BGMs and SEs.
 */
public class SoundManager: abagames.util.sdl.sound.SoundManager {
 private static:
  char[][] seFileName =
    ["shot.wav", "hit.wav", "bullethit.wav", "destroyed.wav", "addtail.wav",
     "breaktail.wav", "enhancedshot.wav", "shipdestroyed.wav", "extend.wav"];
  int[] seChannel =
    [0, 1, 2, 3, 4, 5, 0, 6, 7];
  Music[char[]] bgm;
  Chunk[char[]] se;
  bool[char[]] seMark;
  Rand rand;
  char[][] bgmFileName;
  char[] currentBgm;
  int prevBgmIdx;
  int nextIdxMv;
  bool bgmDisabled = false;
  bool seDisabled = false;

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void loadSounds() {
    loadMusics();
    loadChunks();
    rand = new Rand;
  }

  private static void loadMusics() {
    Music[char[]] musics;
    char[][] files = listdir(Music.dir);
    foreach (char[] fileName; files) {
      char[] ext = getExt(fileName);
      if (ext != "ogg" && ext != "wav")
        continue;
      Music music = new Music();
      music.load(fileName);
      bgm[fileName] = music;
      bgmFileName ~= fileName;
      Logger.info("Load bgm: " ~ fileName);
    }
  }

  private static void loadChunks() {
    int i = 0;
    foreach (char[] fileName; seFileName) {
      Chunk chunk = new Chunk();
      chunk.load(fileName, seChannel[i]);
      se[fileName] = chunk;
      seMark[fileName] = false;
      Logger.info("Load SE: " ~ fileName);
      i++;
    }
  }

  public static void playBgm(char[] name) {
    currentBgm = name;
    if (bgmDisabled)
      return;
    Music.haltMusic();
    bgm[name].play();
  }

  public static void playBgm() {
    int bgmIdx = rand.nextInt(bgm.length);
    nextIdxMv = rand.nextInt(2) * 2 - 1;
    prevBgmIdx = bgmIdx;
    playBgm(bgmFileName[bgmIdx]);
  }

  public static void nextBgm() {
    int bgmIdx = prevBgmIdx + nextIdxMv;
    if (bgmIdx < 0)
      bgmIdx = bgm.length - 1;
    else if (bgmIdx >= bgm.length)
      bgmIdx = 0;
    prevBgmIdx = bgmIdx;
    playBgm(bgmFileName[bgmIdx]);
  }

  public static void playCurrentBgm() {
    playBgm(currentBgm);
  }

  public static void fadeBgm() {
    Music.fadeMusic();
  }

  public static void haltBgm() {
    Music.haltMusic();
  }

  public static void playSe(char[] name) {
    if (seDisabled)
      return;
    seMark[name] = true;
  }

  public static void playMarkedSes() {
    char[][] keys = seMark.keys;
    foreach (char[] key; keys) {
      if (seMark[key]) {
        se[key].play();
        seMark[key] = false;
      }
    }
  }

  public static void clearMarkedSes() {
    char[][] keys = seMark.keys;
    foreach (char[] key; keys)
      seMark[key] = false;
  }

  public static void disableSe() {
    seDisabled = true;
  }

  public static void enableSe() {
    seDisabled = false;
  }

  public static void disableBgm() {
    bgmDisabled = true;
  }

  public static void enableBgm() {
    bgmDisabled = false;
  }
}
