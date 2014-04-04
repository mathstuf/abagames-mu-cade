/*
 * $Id: stagemanager.d,v 1.4 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.stagemanager;

private import std.math;
private import std.string;
private import std.stream;
private import opengl;
private import ode.ode;
private import abagames.util.tokenizer;
private import abagames.util.iterator;
private import abagames.util.rand;
private import abagames.util.vector;
private import abagames.util.ode.world;
private import abagames.mcd.field;
private import abagames.mcd.ship;
private import abagames.mcd.enemy;
private import abagames.mcd.spec;
private import abagames.mcd.particle;
private import abagames.mcd.shot;
private import abagames.mcd.bullet;
private import abagames.mcd.bulletpool;
private import abagames.mcd.soundmanager;

/**
 * Enemy appearance pattern handler.
 */
public class StageManager {
 private:
  static const int MAX_BLOCKS_NUM = 16;
  Field field;
  BulletPool bullets;
  EnemyPool enemies;
  Rand rand;
  float rank, trgRank;
  Appearance[32] appearances;
  int appearanceIdx, appearanceNextIdx;
  float appearanceCnt;
  EnemySpec _blockSpec;
  int cnt;
  int rankDownCnt;

  public this(Field field, Ship ship, BulletPool bullets, World world, EnemyPool enemies) {
    this.field = field;
    this.bullets = bullets;
    this.enemies = enemies;
    rand = new Rand;
    foreach (inout Appearance a; appearances)
      a = new Appearance(field, ship, bullets, world, this);
    _blockSpec = new Block(field, ship, bullets, world);
  }

  public void start(long randSeed) {
    initRank();
    rand.setSeed(randSeed);
    Enemy.setRandSeed(randSeed);
    EnemySpec.setRandSeed(randSeed);
    SimpleBullet.setRandSeed(randSeed);
    Ship.setRandSeed(randSeed);
    ShipTail.setRandSeed(randSeed);
    Shot.setRandSeed(randSeed);
    EnhancedShot.setRandSeed(randSeed);
    Particle.setRandSeed(randSeed);
    ConnectedParticle.setRandSeed(randSeed);
    TailParticle.setRandSeed(randSeed);
    Field.setRandSeed(randSeed);
    SoundManager.setRandSeed(randSeed);
    dRandSetSeed(randSeed);
    clearAppearances();
    cnt = 0;
    rankDownCnt = 0;
  }

  public void initRank() {
    rank = 0;
    trgRank = 30;
  }

  private void clearAppearances() {
    appearanceIdx = appearanceNextIdx = 0;
    appearanceCnt = 0;
  }

  public void move() {
    cnt++;
    float cntInc = 1.0f + rank * 0.04f;
    int cn = enemies.countCentipedes();
    if (cn <= 0) {
      appearanceCnt = -1;
    } else {
      cntInc *= 1 + 1 / cn;
    }
    appearanceCnt -= cntInc;
    if (appearanceCnt < 0) {
      int atypeMax = cast(int) (rank * 2.4f);
      if (atypeMax > 16)
        atypeMax = 16;
      int atype = rand.nextInt(atypeMax);
      switch (atype) {
      case 0:
        addAppearance(rank, Appearance.EnemyType.CHASE, 0, 3, 500);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 6, 250);
        appearanceCnt += 1500;
        break;
      case 1:
        addAppearance(rank, Appearance.EnemyType.TO_AND_FROM, 0, 3, 500);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 6, 250);
        appearanceCnt += 1500;
        break;
      case 2:
        addAppearance(rank, Appearance.EnemyType.ROLL, 0, 3, 30);
        appearanceCnt += 1200;
        break;
      case 3:
        addAppearance(rank, Appearance.EnemyType.CHASE, 0, 5, 20);
        appearanceCnt += 1600;
        break;
      case 4:
        addAppearance(rank * 1.1f, Appearance.EnemyType.CHASE, 1, 1, 1);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 10, 20);
        appearanceCnt += 800;
        break;
      case 5:
        addAppearance(rank * 0.9f, Appearance.EnemyType.CHASE, 0, 3, 500);
        addAppearance(rank * 0.9f, Appearance.EnemyType.TO_AND_FROM, 0, 3, 500);
        appearanceCnt += 1800;
        break;
      case 6:
        addAppearance(rank * 1.1f, Appearance.EnemyType.TO_AND_FROM, 1, 2, 400);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 9, 120);
        appearanceCnt += 1000;
        break;
      case 7:
        addAppearance(rank * 0.9f, Appearance.EnemyType.CHASE, 0, 3, 500);
        addAppearance(rank * 0.9f, Appearance.EnemyType.ROLL, 0, 3, 500);
        appearanceCnt += 1800;
        break;
      case 8:
        addAppearance(rank * 1.1f, Appearance.EnemyType.ROLL, 1, 1, 1);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 10, 20);
        appearanceCnt += 800;
        break;
      case 9:
        addAppearance(rank, Appearance.EnemyType.CHASE, 0, 7, 15);
        appearanceCnt += 2000;
        break;
      case 10:
        addAppearance(rank, Appearance.EnemyType.CHASE, 1, 1, 1);
        addAppearance(rank * 0.8, Appearance.EnemyType.TO_AND_FROM, 1, 3, 400);
        appearanceCnt += 1200;
        break;
      case 11:
        addAppearance(rank * 1.1f, Appearance.EnemyType.TO_AND_FROM, 2, 1, 1);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 8, 60);
        appearanceCnt += 1000;
        break;
      case 12:
        addAppearance(rank, Appearance.EnemyType.CHASE, 0, 5, 300);
        addAppearance(rank, Appearance.EnemyType.TO_AND_FROM, 2, 2, 400);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 6, 350);
        appearanceCnt += 2000;
        break;
      case 13:
        addAppearance(rank, Appearance.EnemyType.CHASE, 2, 1, 1);
        addAppearance(rank, Appearance.EnemyType.CHASE, 0, 3, 20);
        appearanceCnt += 1200;
        break;
      case 14:
        addAppearance(rank * 1.1f, Appearance.EnemyType.ROLL, 2, 1, 1);
        addAppearance(0, Appearance.EnemyType.BLOCK, 0, 10, 60);
        appearanceCnt += 1000;
        break;
      case 15:
        addAppearance(rank, Appearance.EnemyType.TO_AND_FROM, 1, 2, 250);
        addAppearance(rank, Appearance.EnemyType.CHASE, 1, 2, 250);
        appearanceCnt += 2000;
        break;
      }
    }
    bool forced = false;
    if (cn <= 0)
      forced = true;
    int idx = appearanceIdx;
    for (int i = 0; i < appearances.length; i++) {
      if (idx == appearanceNextIdx)
        break;
      if (!appearances[idx].move(rand, cntInc, forced)) {
        if (idx == appearanceIdx) {
          appearanceIdx++;
          if (appearanceIdx >= appearances.length)
            appearanceIdx = 0;
        }
      }
      idx++;
      if (idx >= appearances.length)
        idx = 0;
    }
    if (rank > trgRank * 0.9f)
      rank = trgRank * 0.9f;
    rank += trgRank / sqrt(trgRank - rank) * 0.0006f;
  }

  public void downRank() {
    if (rankDownCnt % 2 == 0) {
      rank *= 0.5f;
    } else {
      rank *= 0.1f;
      enemies.slowdown();
      bullets.slowdown();
      clearAppearances();
      appearanceCnt = 120;
    }
    trgRank += 20 / sqrt(trgRank / 30);
    rankDownCnt++;
  }

  public void addAppearance(float rank, int type, int size, int num, int interval) {
    Appearance a = appearances[appearanceNextIdx];
    appearanceNextIdx++;
    if (appearanceNextIdx >= appearances.length)
      appearanceNextIdx = 0;
    a.set(rank, type, size, num, interval);
  }

  public Enemy set(EnemySpec es, float x, float y, float z, float deg,
                   float sx = 1, float sy = 1, float sz = 1,
                   float massScale = 1) {
    Enemy e;
    if (cast(Block) es && enemies.countBlocks > MAX_BLOCKS_NUM)
      return null;
    if (cast(JointedEnemySpec) es) {
      e = (cast(JointedEnemySpec) es).setJointedEnemies(enemies, x, y, z, deg);
    } else {
      e = enemies.getInstance();
      if (!e)
        return null;
      if (!e.set(es, x, y, z, deg, sx, sy, sz, massScale))
        return null;
    }
    return e;
  }

  public EnemySpec blockSpec() {
    return _blockSpec;
  }
}

/**
 * Data of an enemy appearance pattern.
 */
public class Appearance {
 public:
  static enum EnemyType {
    TO_AND_FROM, CHASE, ROLL, BLOCK,
  };
  static enum AppearanceType {
    NORMAL, BLOCK,
  };
 private:
  Field field;
  Ship ship;
  BulletPool bullets;
  World world;
  StageManager stageManager;
  EnemySpec spec;
  Vector blockAppPos;
  float cnt;
  int num;
  int interval;
  int appType;

  public this(Field field, Ship ship, BulletPool bullets, World world,
              StageManager stageManager) {
    this.field = field;
    this.ship = ship;
    this.bullets = bullets;
    this.world = world;
    this.stageManager = stageManager;
    blockAppPos = new Vector;
    num = 0;
  }

  public void set(float rank, int type, int size, int num, int interval) {
    appType = AppearanceType.NORMAL;
    switch (type) {
    case EnemyType.TO_AND_FROM:
      spec = new CentHeadToAndFrom(field, ship, bullets, world, rank, size);
      break;
    case EnemyType.CHASE:
      spec = new CentHeadChase(field, ship, bullets, world, rank, size);
      break;
    case EnemyType.ROLL:
      spec = new CentHeadRoll(field, ship, bullets, world, rank, size);
      break;
    case EnemyType.BLOCK:
      spec = stageManager.blockSpec;
      appType = AppearanceType.BLOCK;
      blockAppPos.x = field.size.x * 2;
      blockAppPos.y = field.size.y * 2;
      break;
    }
    this.num = num;
    this.interval = interval;
    cnt = 0;
  }

  public bool move(Rand rand, float cntInc, bool forced) {
    if (num <= 0)
      return false;
    if (forced) {
      if (cnt > 5)
        cnt = 5;
    }
    cnt -= cntInc;
    if (cnt < 0) {
      cnt = interval;
      switch (appType) {
      case AppearanceType.NORMAL:
        stageManager.set(spec,
                         rand.nextSignedFloat(field.size.x * 0.5f),
                         rand.nextSignedFloat(field.size.y * 0.5f), 10,
                         rand.nextSignedFloat(PI));
        break;
      case AppearanceType.BLOCK:
        float xs = 1 + rand.nextFloat(1);
        float ys = 1 + rand.nextFloat(1);
        float zs = 1 + rand.nextFloat(1);
        if (rand.nextInt(3) == 0) {
          switch (rand.nextInt(3)) {
          case 0:
            xs *= (2 + rand.nextFloat(2));
            break;
          case 1:
            ys *= (2 + rand.nextFloat(2));
            break;
          case 2:
            zs *= (2 + rand.nextFloat(2));
            break;
          }
        }
        if (fabs(blockAppPos.x) >= field.size.x)
          blockAppPos.x = rand.nextSignedFloat(field.size.x * 0.5f);
        if (fabs(blockAppPos.y) >= field.size.y)
          blockAppPos.y = rand.nextSignedFloat(field.size.y * 0.5f);
        stageManager.set(spec,
                         blockAppPos.x, blockAppPos.y, 10,
                         rand.nextSignedFloat(PI),
                         xs, ys, zs, xs * ys * zs);
        blockAppPos.x += rand.nextSignedFloat(0.5f);
        blockAppPos.y += rand.nextSignedFloat(0.5f);
        break;
      }
      num--;
    }
    return true;
  }
}
