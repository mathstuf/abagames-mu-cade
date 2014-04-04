/*
 * $Id: gamemanager.d,v 1.4 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.gamemanager;

private import std.math;
private import SDL;
private import opengl;
private import openglu;
private import ode.ode;
private import abagames.util.rand;
private import abagames.util.sdl.gamemanager;
private import abagames.util.sdl.twinstickpad;
private import abagames.util.sdl.recordableinput;
private import abagames.util.ode.world;
private import abagames.util.ode.odeactor;
private import abagames.mcd.field;
private import abagames.mcd.screen;
private import abagames.mcd.enemy;
private import abagames.mcd.spec;
private import abagames.mcd.ship;
private import abagames.mcd.shot;
private import abagames.mcd.particle;
private import abagames.mcd.stagemanager;
private import abagames.mcd.letter;
private import abagames.mcd.bullet;
private import abagames.mcd.bulletpool;
private import abagames.mcd.barrage;
private import abagames.mcd.replay;
private import abagames.mcd.soundmanager;
private import abagames.mcd.title;
private import abagames.mcd.prefmanager;

/**
 * Game lifecycle management.
 */
public class GameManager: abagames.util.sdl.gamemanager.GameManager {
 private:
  static const char[] LAST_REPLAY_FILE_NAME = "last.rpl";
  static const int RANK_DOWN_INTERVAL = 60 * 1000;
  static const int BGM_CHANGE_INTERVAL = 2 * 60 * 1000;
  static const enum GameState {
    TITLE, REPLAY, IN_GAME,
  };
  RecordableTwinStickPad pad;
  Screen screen;
  World world;
  Field field;
  EnemyPool enemies;
  BulletPool bullets;
  Ship ship;
  ParticlePool particles;
  ConnectedParticlePool connectedParticles;
  TailParticlePool tailParticles;
  StarParticlePool starParticles;
  NumIndicatorPool numIndicators;
  StageManager stageManager;
  TitleManager titleManager;
  ReplayData _replayData;
  Rand rand;
  int score;
  int nextExtendScore;
  int time;
  int rankDownTime;
  int bgmChangeTime;
  int bgmStartCnt;
  int left;
  int state;
  bool escPressed, pPressed, aPressed;
  bool paused;
  int pauseCnt;
  bool _isGameOver;
  int gameOverCnt;
  PrefManager prefManager;

  public override void init() {
    BarrageManager.load();
    SoundManager.loadSounds();
    prefManager = cast(PrefManager) abstPrefManager;
    prefManager.load();
    OdeActor.initFirst();
    Letter.init();
    Ship.init();
    Enemy.init();
    SimpleBullet.init();
    Particle.init();
    ConnectedParticle.init();
    TailParticle.init();
    Field.init();
    pad = cast(RecordableTwinStickPad) input;
    pad.openJoystick();
    screen = cast(Screen) abstScreen;
    world = new World;
    //world.init();
    field = new Field(screen, world, this);
    screen.setField(field);
    Object[] pargs;
    pargs ~= field;
    particles = new ParticlePool(256, pargs);
    connectedParticles = new ConnectedParticlePool(540, pargs);
    starParticles = new StarParticlePool(128, pargs);
    numIndicators = new NumIndicatorPool(16, null);
    field.setStarParticles(starParticles);
    ship = new Ship(world, pad, field, screen, particles, connectedParticles, this);
    field.setShip(ship);
    Object[] tpargs;
    tpargs ~= field;
    tpargs ~= ship;
    tailParticles = new TailParticlePool(32, tpargs);
    Object[] bargs;
    bargs ~= field;
    bargs ~= ship;
    bargs ~= this;
    bargs ~= particles;
    bargs ~= world;
    bullets = new BulletPool(256, 256, bargs);
    ship.setBullets(bullets);
    Object[] eargs;
    eargs ~= field;
    eargs ~= particles;
    eargs ~= connectedParticles;
    eargs ~= tailParticles;
    eargs ~= numIndicators;
    eargs ~= ship;
    eargs ~= this;
    enemies = new EnemyPool(64, eargs);
    enemies.init(world);
    stageManager = new StageManager(field, ship, bullets, world, enemies);
    titleManager = new TitleManager(field, stageManager, prefManager);
    rand = new Rand;
    //loadLastReplay();
  }

  public override void start() {
    score = time = 0;
    startTitle();
  }

  public void startInGame() {
    state = GameState.IN_GAME;
    ship.replayMode = false;
    _replayData = new ReplayData;
    RecordableTwinStickPad rtsp = cast(RecordableTwinStickPad) pad;
    rtsp.startRecord();
    _replayData.twinStickPadInputRecord = rtsp.inputRecord;
    _replayData.seed = rand.nextInt32();
    initGame();
    score = 0;
    time = 0;
    SoundManager.playBgm();
  }

  public void startTitle() {
    SoundManager.haltBgm();
    titleManager.start();
    restartTitle();
  }

  public void restartTitle() {
    /*if (_replayData) {
      state = GameState.REPLAY;
      ship.replayMode = true;
      RecordableTwinStickPad rtsp = cast(RecordableTwinStickPad) pad;
      rtsp.startReplay(_replayData.twinStickPadInputRecord);
      score = 0;
      time = 0;
    } else {*/
      state = GameState.TITLE;
      _replayData = new ReplayData;
      _replayData.seed = rand.nextInt32();
    //}
    initGame();
    aPressed = true;
  }

  private void initGame() {
    clearAll();
    world.init();
    ship.start();
    field.start();
    stageManager.start(_replayData.seed);
    SoundManager.clearMarkedSes();
    _isGameOver = false;
    paused = false;
    rankDownTime = RANK_DOWN_INTERVAL;
    bgmChangeTime = BGM_CHANGE_INTERVAL;
    bgmStartCnt = -1;
    nextExtendScore = 50000;
    left = 0;
  }

  private void clearAll() {
    enemies.clear();
    bullets.clear();
    ship.clear();
    particles.clear();
    connectedParticles.clear();
    tailParticles.clear();
    starParticles.clear();
    numIndicators.clear();
    field.clear();
    world.close();
  }

  public override void close() {
    world.close();
    SoundManager.haltBgm();
    Letter.close();
    BarrageManager.unload();
  }

  public override void move() {
    handleEscKey();
    if (state == GameState.IN_GAME && !_isGameOver) {
      handlePauseKey();
      if (paused) {
        pauseCnt++;
        return;
      }
    }
    field.move();
    stageManager.move();
    world.resetJointFeedback();
    enemies.clearContactJoint();
    ship.clearContactJoint();
    enemies.move();
    bullets.move();
    switch (state) {
    case GameState.IN_GAME:
    case GameState.REPLAY:
      ship.move();
      break;
    case GameState.TITLE:
      ship.moveInTitle();
      break;
    }
    particles.move();
    connectedParticles.move();
    connectedParticles.recordLinePoints();
    tailParticles.move();
    starParticles.move();
    numIndicators.move();
    world.move(0.05);
    enemies.checkFeedbackForce();
    ship.checkFeedbackForce();
    world.removeAllContactJoints();
    if (state != GameState.TITLE) {
      if (!_isGameOver) {
        handleRank();
        handleSound();
        time += 16;
      } else {
        gameOverCnt++;
        if (gameOverCnt < 60)
          handleSound();
        if (gameOverCnt > 1000)
          startTitle();
      }
    }
    if (state != GameState.IN_GAME) {
      titleManager.move();
      checkGameStart();
    }
  }

  private void handleEscKey() {
    if (pad.keys[SDLK_ESCAPE] == SDL_PRESSED) {
      if (!escPressed) {
        escPressed = true;
        if (state == GameState.IN_GAME)
          startTitle();
        else
          mainLoop.breakLoop();
      }
    } else {
      escPressed = false;
    }
  }

  private void handlePauseKey() {
    if (pad.keys[SDLK_p] == SDL_PRESSED) {
      if (!pPressed) {
        pPressed = true;
        paused = !paused;
        pauseCnt = 0;
      }
    } else {
      pPressed = false;
    }
  }

  public void checkGameStart() {
    TwinStickPadState input;
    input = pad.getState(false);
    if (input.button & TwinStickPadState.Button.A) {
      if (!aPressed)
        startInGame();
      aPressed = true;
    } else {
      aPressed = false;
    }
  }

  private void handleRank() {
    if (time >= rankDownTime) {
      stageManager.downRank();
      rankDownTime += RANK_DOWN_INTERVAL;
    }
  }

  private void handleSound() {
    if (state != GameState.IN_GAME)
      return;
    SoundManager.playMarkedSes();
    if (time >= bgmChangeTime) {
      SoundManager.fadeBgm();
      bgmChangeTime += BGM_CHANGE_INTERVAL;
      bgmStartCnt = 180;
    }
    if (bgmStartCnt > 0) {
      bgmStartCnt--;
      if (bgmStartCnt == 0)
        SoundManager.nextBgm();
    }
  }

  public void addScore(int sc) {
    if (state == GameState.TITLE || _isGameOver)
      return;
    score += sc;
    if (score >= nextExtendScore) {
      if (left < 2) {
        left++;
        SoundManager.playSe("extend.wav");
      }
      if (nextExtendScore < 200000)
        nextExtendScore = 0;
      nextExtendScore += 200000;
    }
  }

  public void shipDestroyed() {
    left--;
    if (left < 0)
      startGameOver();
  }

  public void startGameOver() {
    if (_isGameOver || state == GameState.TITLE)
      return;
    _isGameOver = true;
    gameOverCnt = 0;
    SoundManager.fadeBgm();
    if (state == GameState.REPLAY)
      return;
    prefManager.prefData.recordResult(score, time);
    prefManager.save();
    //saveLastReplay();
  }

  public void backToTitle() {
    if (gameOverCnt > 60)
      startTitle();
  }

  public override void draw() {
    SDL_Event e = mainLoop.event;
    if (e.type == SDL_VIDEORESIZE) {
      SDL_ResizeEvent re = e.resize;
      if (re.w > 150 && re.h > 100)
        screen.resized(re.w, re.h);
    }
    if (state == GameState.IN_GAME || state == GameState.REPLAY)
      field.setLookAt();
    else
      field.setLookAtTitle();
    Screen.setColor(1, 1, 1);
    glBegin(GL_LINES);
    starParticles.draw();
    glEnd();
    if (state == GameState.IN_GAME || state == GameState.REPLAY)
      field.draw();
    enemies.drawSpectrum();
    if (state == GameState.IN_GAME || state == GameState.REPLAY) {
      enemies.drawShadow();
      enemies.draw();
    }
    particles.draw();
    connectedParticles.draw();
    if (state == GameState.IN_GAME || state == GameState.REPLAY)
      tailParticles.draw();
    bullets.drawSpectrum();
    if (state == GameState.IN_GAME || state == GameState.REPLAY) {
      bullets.drawShadow();
      bullets.draw();
      ship.draw();
      numIndicators.draw();
    }
    field.drawOverlay();
  }

  public void drawState() {
    Letter.drawNum(score, 120, 21, 6);
    Letter.drawTime(time, 610, 30, 6);
    switch (state) {
    case GameState.IN_GAME:
    case GameState.REPLAY:
      if (left > 0) {
        float x = 320 - (left - 1) * 12;
        for (int i = 0; i < left; i++) {
          ship.drawLeft(x, 35);
          x += 24;
        }
      }
      if (_isGameOver) {
        if (gameOverCnt > 60)
          Letter.drawString("GAME OVER", 214, 200, 12);
      } else if (paused) {
        if (pauseCnt % 120 < 60)
          Letter.drawString("PAUSE", 290, 420, 7);
      }
      if (state == GameState.IN_GAME)
        break;
    case GameState.TITLE:
      titleManager.draw();
      break;
    }
  }

  public bool isGameOver() {
    return _isGameOver;
  }

  public bool isGameOver(bool v) {
    return _isGameOver = v;
  }

  // Handle a replay data.
  // Replay functions are disabled because of bugs.
  private void saveLastReplay() {
    try {
      saveReplay(LAST_REPLAY_FILE_NAME);
    } catch (Object o) {}
  }

  private void loadLastReplay() {
    try {
      loadReplay(LAST_REPLAY_FILE_NAME);
    } catch (Object o) {
      resetReplay();
    }
  }

  private void saveReplay(char[] fileName) {
    _replayData.save(fileName);
  }

  private void loadReplay(char[] fileName) {
    _replayData = new ReplayData;
    _replayData.load(fileName);
  }

  private void resetReplay() {
    _replayData = null;
  }
}
