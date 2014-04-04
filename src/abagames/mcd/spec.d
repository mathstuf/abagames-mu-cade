/*
 * $Id: spec.d,v 1.3 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.spec;

private import std.math;
private import opengl;
private import ode.ode;
private import abagames.util.vector;
private import abagames.util.math;
private import abagames.util.ode.odeactor;
private import abagames.util.ode.world;
private import abagames.mcd.field;
private import abagames.mcd.screen;
private import abagames.mcd.ship;
private import abagames.mcd.shot;
private import abagames.mcd.shape;
private import abagames.mcd.enemy;
private import abagames.mcd.bullet;
private import abagames.mcd.bulletpool;
private import abagames.mcd.barrage;

/**
 * Centipede move.
 */
public template CentMoveImpl() {
 public:
  static enum CentType {
    TO_AND_FROM, CHASE, ROLL,
  };
 protected:
  static const int[][] TURN_TRG_DEG = [
    [ 5,  4,  3, -1, -1, -1,  3,  4],
    [ 5,  6,  7,  6,  5, -1, -1, -1],
    [-1, -1,  7,  0,  1,  0,  7, -1],
    [ 1, -1, -1, -1,  1,  2,  3,  2]];
  static const float SIZE = 1.0f;
  static const float WIDTH = 0.25f;
  static const float MASS = 1.0f;
  static const float FORWARD_FORCE_BASE = 5;
  static const float ANGULAR_FORCE_BASE = 10;
  static const float SLOW_VELOCITY_RATIO = 0.01f;
  static const float SLOW_ANGULAR_RATIO = 0.1f;
  CentHead headSpec;
  int bodyLength, baseSize;

  public override bool move(Enemy enemy, EnemyState state) {
    if (field.checkInField(state.pos)) {
      if (state.isHead)
        enemy.addRelForce(0, FORWARD_FORCE_BASE * state.forwardForceScale);
      if (state.topBullet)
        state.topBullet.activated = true;
      state.linePoint.enableSpectrumColor = true;
      switch (state.type) {
      case CentType.TO_AND_FROM:
        enemy.slowLinearVel(CentHead.SLOW_VELOCITY_RATIO * state.slowVelocityRatio *
                            (1 + (state.turnCnt * 0.1f)));
        break;
      case CentType.CHASE:
        enemy.slowLinearVel(CentHead.SLOW_VELOCITY_RATIO * state.slowVelocityRatio * 0.25f);
        break;
      case CentType.ROLL:
        enemy.slowLinearVel(CentHead.SLOW_VELOCITY_RATIO * state.slowVelocityRatio * 5);
        break;
      }
    } else {
      if (state.topBullet)
        state.topBullet.activated = false;
      state.linePoint.enableSpectrumColor = false;
    }
    enemy.slowAngularVel(CentHead.SLOW_ANGULAR_RATIO);
    if (!state.isHead)
      return true;
    if (field.checkInField(state.pos))
      enemy.slowLinearVel(CentHead.SLOW_VELOCITY_RATIO * state.slowVelocityRatio);
    if (state.turnCnt > 0)
      state.turnCnt--;
    float ad;
    float angularForce = ANGULAR_FORCE_BASE;
    switch (state.type) {
    case CentType.TO_AND_FROM:
      int ti = -1;
      if (state.pos.x > field.size.x * 0.5f)
        ti = 3;
      else if (state.pos.x < -field.size.x * 0.5f)
        ti = 1;
      if (ti >= 0 && TURN_TRG_DEG[ti][state.trgDeg] >= 0) {
        state.trgDeg = TURN_TRG_DEG[ti][state.trgDeg];
        if (state.turnCnt <= 0)
          state.turnCnt = 60;
      } else {
        if (state.pos.y < -field.size.y * 0.5f)
          ti = 2;
        else if (state.pos.y > field.size.y * 0.5f)
          ti = 0;
        if (ti >= 0 && TURN_TRG_DEG[ti][state.trgDeg] >= 0) {
          state.trgDeg = TURN_TRG_DEG[ti][state.trgDeg];
          if (state.turnCnt <= 0)
            state.turnCnt = 60;
        }
      }
      ad = state.trgDeg * PI / 4;
      break;
    case CentType.CHASE:
      ad = atan2(-ship.pos.x + state.pos.x, ship.pos.y - state.pos.y);
      break;
    case CentType.ROLL:
      if (state.nextJointedEnemy) {
        Enemy e = state.nextJointedEnemy;
        EnemyState s;
        for (;;) {
          s = e.getState();
          if (!s.nextJointedEnemy || !s.nextJointedEnemy.exists)
            break;
          e = s.nextJointedEnemy;
        }
        ad = atan2(-s.pos.x + state.pos.x, s.pos.y - state.pos.y);
      } else {
        ad = state.deg + PI / 5;
      }
      float sd = atan2(-ship.pos.x + state.pos.x, ship.pos.y - state.pos.y);
      float sf = FORWARD_FORCE_BASE * state.forwardForceScale * 0.16f;
      enemy.addForce(-sin(sd) * sf, cos(sd) * sf);
      break;
    }
    Math.normalizeDeg(ad);
    ad -= state.deg;
    Math.normalizeDeg(ad);
    float f = ad;
    if (f > 1)
      f = 1;
    else if (f < -1)
      f = -1;
    enemy.addRelForceAtRelPos(0, state.sizeScale.x * SIZE / 2, 0, angularForce * f, 0, 0);
    Enemy e = enemy;
    for (;;) {
      EnemyState s = e.getState();
      e = s.nextJointedEnemy;
      if (!e || !e.exists)
        break;
      s.trgDeg = state.trgDeg;
      s.moveFlag = state.moveFlag;
    }
    enemy.addForce(0, 0, -Field.GRAVITY * state.massScale);
    return true;
  }

  private void remove(Enemy enemy) {
    Enemy e = enemy;
    for (;;) {
      EnemyState s = e.getState();
      e = s.nextJointedEnemy;
      if (!e || !e.exists)
        break;
      e.remove();
    }
  }

  public override void destroyed(Enemy enemy, EnemyState state) {
    if (state.isHead) {
      Enemy e = enemy;
      int idx = 0;
      for (;;) {
        EnemyState s = e.getState();
        e = s.nextJointedEnemy;
        if (!e || !e.exists)
          break;
        e.removeAsTail(idx);
        idx++;
      }
      addConnectedParticlesHead(enemy, state);
      enemy.addScore((baseSize + 1) * 50 + bodyLength * 10);
    }/* else {
      if (state.nextJointedEnemy) {
        Enemy e = state.nextJointedEnemy;
        if (e.exists) {
          EnemyState s = e.getState();
          s.destroyable = s.isHead = true;
          headSpec.setHeadBarrage(state);
          s.turnCnt = 0;
          s.prevJointedEnemy = null;
        }
      }
      if (state.prevJointedEnemy) {
        Enemy e = state.prevJointedEnemy;
        if (e.exists) {
          EnemyState s = e.getState();
          s.nextJointedEnemy = null;
          s.removeAllJoints();
        }
      }
      addConnectedParticlesBody(enemy, state);
    }*/
  }

  private void addConnectedParticlesHead(Enemy enemy, EnemyState state) {
    float d = atan2(state.pos.x, -state.pos.y);
    for (int i = 0; i < 6; i++)
      enemy.addConnectedParticles(d + rand.nextSignedFloat(PI / 4), 6.0f, false);
  }

  public void addConnectedParticlesBody(Enemy enemy, EnemyState state) {
    enemy.addConnectedParticles(state.deg + PI / 2, 1.5f * state.sizeScale.x);
    enemy.addConnectedParticles(state.deg - PI / 2, 1.5f * state.sizeScale.x);
  }

  public override void drawSubShape(EnemyState state) {
    if (state.isHead) {
      glPushMatrix();
      Screen.glTranslate(state.pos);
      glMultMatrixd(state.rot);
      glScalef(state.sizeScale.x, state.sizeScale.y, state.sizeScale.z);
      subShape.draw();
      glPopMatrix();
    }
  }
}

/**
 * Centipede barrage pattern.
 */
public class CentBarrage {
 public:
  static enum BasicBarrageType {
    AIM, FRONT, PLUMB, SIDE, ONE_SIDE, AIM_IN_ORDER,
  };
  BasicBarrageType type;
  float speedRank;
  int interval;
  char[] wayMorphBml;
  float wayMorphRank;
  char[] barMorphBml;
  float barMorphRank;
 private:

  invariant {
    assert(speedRank > 0 && speedRank < 10);
    assert(interval > 0);
  }

  public void set(BulletPool bullets, Ship ship, EnemyState state, float orderRatio = 0) {
    state.barrage.clear();
    switch (type) {
    case BasicBarrageType.AIM:
    case BasicBarrageType.FRONT:
    case BasicBarrageType.PLUMB:
    case BasicBarrageType.AIM_IN_ORDER:
      state.barrage.addBml("basic", "straight.xml", 1, speedRank);
      break;
    case BasicBarrageType.SIDE:
      state.barrage.addBml("basic", "side.xml", 1, speedRank);
      break;
    case BasicBarrageType.ONE_SIDE:
      state.barrage.addBml("basic", "sideoneway.xml", 1, speedRank);
      break;
    }
    if (wayMorphBml)
      state.barrage.addBml("waymorph", wayMorphBml, wayMorphRank, speedRank);
    if (barMorphBml)
      state.barrage.addBml("barmorph", barMorphBml, barMorphRank, speedRank);
    int sc = 0;
    if (type == BasicBarrageType.AIM_IN_ORDER)
      sc = cast(int) (interval * orderRatio);
    state.barrage.setWait(sc, interval);
    state.topBullet = state.barrage.addTopBullet(bullets, ship);
    if (!state.topBullet)
      return;
    state.topBullet.activated = false;
    switch (type) {
    case BasicBarrageType.AIM:
    case BasicBarrageType.AIM_IN_ORDER:
      break;
    case BasicBarrageType.FRONT:
    case BasicBarrageType.SIDE:
    case BasicBarrageType.ONE_SIDE:
      state.setTopBulletDirection = true;
      state.topBullet.unsetAimTop();
      break;
    case BasicBarrageType.PLUMB:
      state.setPlumbDirection = true;
      state.topBullet.unsetAimTop();
      break;
    }
  }
}

public template CentHeadInitImpl() {
  protected void initLengthAndSize(int size) {
    float ss;
    switch (size) {
    case 0:
      bodyLength = 4 + rand.nextInt(4);
      ss = 0.9f + rand.nextFloat(0.3f);
      break;
    case 1:
      bodyLength = 5 + rand.nextInt(3);
      ss = 1.3f + rand.nextFloat(0.2f);
      break;
    case 2:
      bodyLength = 7 + rand.nextInt(2);
      ss = 1.6f + rand.nextFloat(0.1f);
      break;
    }
    baseSize = size;
    sizeScale = new Vector3(ss, ss, 1);
    massScale = ss * ss;
  }

  protected float calcBarrageRank(float br) {
    if (br < 0.01f)
      return 0;
    else
      return 1 - 1 / sqrt(br);
  }

  protected void calcBarrageSpeedAndInterval(
    inout float rank, float br, out float speed, out int interval,
    float minInterval = 20, float maxInterval = 120) {
    float sr = br * (0.5f + rand.nextSignedFloat(0.2f));
    float ir = br - sr;
    if (sr < 1) {
      sr = 1;
    } else {
      rank -= sr;
      sr = 2.5 - 1.5 / sqrt(sr);
    }
    speed = sr;
    if (ir < 1)
      ir = 1;
    else
      rank -= ir;
    interval = cast(int) (minInterval + (maxInterval - minInterval) / ir);
  }

  protected void calcForwardForceAndSlowVelocity(
    inout float rank, int size,
    out float forwardForceScale, out float slowVelocityRatio) {
    forwardForceScale = 1;
    if (rand.nextInt(5) == 0) {
      float ff = rank * (0.1f + rand.nextFloat(0.3f - size * 0.1f));
      if (ff < 0)
        ff = 0;
      forwardForceScale = 1 + sqrt(ff);
      rank -= ff * 0.2f;
    }
    forwardForceScale *= cast(float) bodyLength / 5;
    slowVelocityRatio = 1;
    if (size >= 1) {
      float sv = rank * (0.1f + rand.nextFloat(0.1f)) * size;
      if (sv < 0)
        sv = 0;
      slowVelocityRatio = 1 + sv * 3;
      rank -= sv * 0.2f;
    }
  }
}

/**
 * Centipede head specs.
 */
public class CentHeadToAndFrom: CentHead {
  mixin CentHeadInitImpl;
 public:
  static const float COLOR_R = 0.5f;
  static const float COLOR_G = 0.25f;
  static const float COLOR_B = 1.0f;
 private:
  static const char[][] BAR_MORPH_BML = [
    "baraccel.xml", "whip.xml", "slidebar.xml", "slidebaraccel.xml", "slidewhip.xml"];

  public this(Field field, Ship ship, BulletPool bullets, World world, float rank, int size) {
    super(field, ship, bullets, world);
    headSpec = this;
    bodySpec = new CentBodyToAndFrom(field, ship, bullets, world, this);
    initLengthAndSize(size);
    float rk = rank;
    if (size <= 0) {
      bodyBarrage = null;
    } else {
      bodyBarrage = new CentBarrage;
      if (rand.nextInt(2) == 0)
        bodyBarrage.type = CentBarrage.BasicBarrageType.PLUMB;
      else
        bodyBarrage.type = CentBarrage.BasicBarrageType.SIDE;
      bodyBarrage.wayMorphBml = null;
      float br = rk * (0.1f * size + rand.nextFloat(0.1f));
      float brv = calcBarrageRank(br);
      if (brv >= 0.1f) {
        bodyBarrage.barMorphBml = BAR_MORPH_BML[rand.nextInt(BAR_MORPH_BML.length)];
        bodyBarrage.barMorphRank = brv;
        rk -= br * 2;
      } else {
        bodyBarrage.barMorphBml = null;
      }
      float sp;
      int iv;
      calcBarrageSpeedAndInterval(rk, rk * 0.25f, sp, iv, 20, 150);
      bodyBarrage.speedRank = sp;
      bodyBarrage.interval = iv;
    }
    headBarrage = new CentBarrage;
    headBarrage.type = CentBarrage.BasicBarrageType.FRONT;
    headBarrage.wayMorphBml = null;
    float br = rk * (0.1f * size + rand.nextFloat(0.3f));
    float brv = calcBarrageRank(br);
    if (brv >= 0.1f) {
      headBarrage.barMorphBml = BAR_MORPH_BML[rand.nextInt(BAR_MORPH_BML.length)];
      headBarrage.barMorphRank = brv;
      rk -= br * 2;
    } else {
      headBarrage.barMorphBml = null;
    }
    float ffs, svr;
    calcForwardForceAndSlowVelocity(rk, size, ffs, svr);
    forwardForceScale = ffs;
    slowVelocityRatio = svr;
    float sp;
    int iv;
    switch (size) {
    case 0:
      calcBarrageSpeedAndInterval(rk, rk, sp, iv);
      break;
    case 1:
      calcBarrageSpeedAndInterval(rk, rk, sp, iv, 10, 90);
      break;
    case 2:
      calcBarrageSpeedAndInterval(rk, rk, sp, iv, 5, 60);
      break;
    }
    headBarrage.speedRank = sp;
    headBarrage.interval = iv;
    _colorR = COLOR_R;
    _colorG = COLOR_G;
    _colorB = COLOR_B;
  }

  public override void initState(Enemy enemy, EnemyState state) {
    state.type = CentType.TO_AND_FROM;
    super.initState(enemy, state);
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 1.0f);
  }
}

public class CentHeadChase: CentHead {
  mixin CentHeadInitImpl;
 public:
  static const float COLOR_R = 0.75f;
  static const float COLOR_G = 0.25f;
  static const float COLOR_B = 0.75f;
 private:
  static const char[][] WAY_MORPH_BML = [
    "accnway.xml", "decnway.xml", "nway.xml"];
  static const char[][] BAR_MORPH_BML = [
    "bar.xml", "baraccel.xml", "whip.xml"];

  public this(Field field, Ship ship, BulletPool bullets, World world, float rank, int size) {
    super(field, ship, bullets, world);
    headSpec = this;
    bodySpec = new CentBodyChase(field, ship, bullets, world, this);
    initLengthAndSize(size);
    float rk = rank;
    if (size <= 1) {
      bodyBarrage = null;
    } else {
      bodyBarrage = new CentBarrage;
      bodyBarrage.type = CentBarrage.BasicBarrageType.AIM_IN_ORDER;
      bodyBarrage.wayMorphBml = null;
      float br = rk * (0.1f + rand.nextFloat(0.1f));
      float brv = calcBarrageRank(br);
      if (brv >= 0.1f) {
        bodyBarrage.barMorphBml = BAR_MORPH_BML[rand.nextInt(BAR_MORPH_BML.length)];
        bodyBarrage.barMorphRank = brv;
        rk -= br * 2;
      } else {
        bodyBarrage.barMorphBml = null;
      }
      float sp;
      int iv;
      calcBarrageSpeedAndInterval(rk, rk * 0.2f, sp, iv);
      bodyBarrage.speedRank = sp;
      bodyBarrage.interval = iv;
    }
    headBarrage = new CentBarrage;
    headBarrage.type = CentBarrage.BasicBarrageType.FRONT;
    float wr;
    switch (size) {
    case 0:
      wr = 0;
      break;
    case 1:
      wr = rk * (0.2f + rand.nextFloat(0.1f));
      break;
    case 2:
      wr = rk * (0.1f + rand.nextFloat(0.1f));
      break;
    }
    float br = rk * rand.nextFloat(0.3f);
    float wrv = calcBarrageRank(wr);
    float brv = calcBarrageRank(br);
    if (wrv >= 0.2f) {
      headBarrage.wayMorphBml = WAY_MORPH_BML[rand.nextInt(WAY_MORPH_BML.length)];
      headBarrage.wayMorphRank = wrv;
      rk -= wr * 2;
    } else {
      headBarrage.wayMorphBml = null;
    }
    if (brv >= 0.1f) {
      headBarrage.barMorphBml = BAR_MORPH_BML[rand.nextInt(BAR_MORPH_BML.length)];
      headBarrage.barMorphRank = brv;
      rk -= br * 2;
    } else {
      headBarrage.barMorphBml = null;
    }
    float ffs, svr;
    calcForwardForceAndSlowVelocity(rk, size, ffs, svr);
    forwardForceScale = ffs;
    slowVelocityRatio = svr;
    float sp;
    int iv;
    if (size <= 0)
      calcBarrageSpeedAndInterval(rk, rk, sp, iv);
    else
      calcBarrageSpeedAndInterval(rk, rk, sp, iv, 10, 90);
    headBarrage.speedRank = sp;
    headBarrage.interval = iv;
    _colorR = COLOR_R;
    _colorG = COLOR_G;
    _colorB = COLOR_B;
  }

  public override void initState(Enemy enemy, EnemyState state) {
    state.type = CentType.CHASE;
    super.initState(enemy, state);
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 1.0f);
  }
}

public class CentHeadRoll: CentHead {
  mixin CentHeadInitImpl;
 public:
  static const float COLOR_R = 0.25f;
  static const float COLOR_G = 0.75f;
  static const float COLOR_B = 0.75f;
 private:
  static const char[][] WAY_MORPH_BML = [
    "nway.xml", "round.xml"];
  static const char[][] BAR_MORPH_BML = [
    "bar.xml", "baraccel.xml", "whip.xml",
    "slidebar.xml", "slidebaraccel.xml", "slidewhip.xml"];

  public this(Field field, Ship ship, BulletPool bullets, World world, float rank, int size) {
    super(field, ship, bullets, world);
    headSpec = this;
    bodySpec = new CentBodyRoll(field, ship, bullets, world, this);
    initLengthAndSize(size);
    bodyLength = 6;
    float rk = rank;
    bodyBarrage = new CentBarrage;
    bodyBarrage.type = CentBarrage.BasicBarrageType.ONE_SIDE;
    bodyBarrage.wayMorphBml = null;
    float br = rk * (0.1f * size + rand.nextFloat(0.1f));
    float brv = calcBarrageRank(br);
    if (brv >= 0.1f) {
      bodyBarrage.barMorphBml = BAR_MORPH_BML[rand.nextInt(BAR_MORPH_BML.length)];
      bodyBarrage.barMorphRank = brv;
      rk -= br * 2;
    } else {
      bodyBarrage.barMorphBml = null;
    }
    float sp;
    int iv;
    switch (size) {
    case 0:
      calcBarrageSpeedAndInterval(rk, rk * 0.5f, sp, iv, 10, 60);
      break;
    case 1:
      calcBarrageSpeedAndInterval(rk, rk * 0.3f, sp, iv, 5, 40);
      break;
    case 2:
      calcBarrageSpeedAndInterval(rk, rk * 0.3f, sp, iv, 3, 24);
      break;
    }
    bodyBarrage.speedRank = sp;
    bodyBarrage.interval = iv;
    if (size <= 0) {
      headBarrage = bodyBarrage;
      float ffs, svr;
      calcForwardForceAndSlowVelocity(rk, size, ffs, svr);
      forwardForceScale = ffs;
      slowVelocityRatio = svr;
    } else {
      headBarrage = new CentBarrage;
      headBarrage.type = CentBarrage.BasicBarrageType.FRONT;
      float wr = rk * (size * 0.2f + rand.nextFloat(0.2f));
      float br = rk * rand.nextFloat(0.2f);
      float wrv = calcBarrageRank(wr);
      float brv = calcBarrageRank(br);
      if (wrv >= 0.2f) {
        headBarrage.wayMorphBml = WAY_MORPH_BML[rand.nextInt(WAY_MORPH_BML.length)];
        headBarrage.wayMorphRank = wrv;
        rk -= wr * 2;
      } else {
        headBarrage.wayMorphBml = null;
      }
      if (brv >= 0.1f) {
        headBarrage.barMorphBml = BAR_MORPH_BML[rand.nextInt(BAR_MORPH_BML.length)];
        headBarrage.barMorphRank = brv;
        rk -= br * 2;
      } else {
        headBarrage.barMorphBml = null;
      }
      float ffs, svr;
      calcForwardForceAndSlowVelocity(rk, size, ffs, svr);
      forwardForceScale = ffs;
      slowVelocityRatio = svr;
      float sp;
      int iv;
      calcBarrageSpeedAndInterval(rk, rk, sp, iv, 10, 60);
      headBarrage.speedRank = sp;
      headBarrage.interval = iv;
    }
    _colorR = COLOR_R;
    _colorG = COLOR_G;
    _colorB = COLOR_B;
  }

  public override void initState(Enemy enemy, EnemyState state) {
    state.type = CentType.ROLL;
    super.initState(enemy, state);
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 1.0f);
  }
}

public class CentHead: EnemySpec, JointedEnemySpec, ConnectedParticlesBodyAddable {
  mixin CentMoveImpl;
 protected:
  EnemySpec bodySpec;
  Vector3 sizeScale;
  float massScale;
  float forwardForceScale;
  float slowVelocityRatio;
  CentBarrage headBarrage, bodyBarrage;
 private:

  invariant {
    if (sizeScale) {
      assert(sizeScale.x > 0);
      assert(sizeScale.y > 0);
      assert(sizeScale.z > 0);
      assert(massScale > 0);
      assert(forwardForceScale > 0);
      assert(slowVelocityRatio > 0);
    }
  }

  public this(Field field, Ship ship, BulletPool bullets, World world) {
    this.field = field;
    this.ship = ship;
    this.bullets = bullets;
    this.world = world;
    shape = new ShapeGroup;
    shape.addShape(new Square(world, MASS, 0, 0, SIZE * WIDTH, SIZE));
    subShape = new EyeShape;
  }

  public override void initState(Enemy enemy, EnemyState state) {
    super.initState(enemy, state);
    setHeadBarrage(state);
    if (state.pos.x < 0) {
      if (state.pos.y < 0)
        state.trgDeg = 7;
      else
        state.trgDeg = 5;
    } else {
      if (state.pos.y < 0)
        state.trgDeg = 1;
      else
        state.trgDeg = 3;
    }
    state.turnCnt = 0;
    state.moveFlag = 0;
    state.forwardForceScale = forwardForceScale;
    state.slowVelocityRatio = slowVelocityRatio;
    state.isHead = true;
  }

  public void setHeadBarrage(EnemyState state) {
    if (state.topBullet) {
      state.topBullet.removeForced();
      state.topBullet = null;
    }
    if (headBarrage)
      headBarrage.set(bullets, ship, state);
  }

  public Enemy setJointedEnemies(EnemyPool enemies, float x, float y, float z, float deg) {
    if (bodyLength <= 0)
      return null;
    Enemy[] je = enemies.getMultipleInstances(bodyLength);
    if (!je)
      return null;
    bool app = true;
    bool isFirst = true;
    float ex = x, ey = y;
    foreach (Enemy e; je) {
      if (isFirst) {
        app &= e.set(this, ex, ey, z, deg, sizeScale, massScale, true);
        isFirst = false;
      } else {
        app &= e.set(bodySpec, ex, ey, z, deg, sizeScale, massScale, true);
      }
      ex +=  sin(deg) * sizeScale.x * SIZE * 1.1f;
      ey += -cos(deg) * sizeScale.x * SIZE * 1.1f;
    }
    if (!app) {
      foreach (Enemy e; je)
        e.remove();
      return null;
    }
    for (int i = 0; i < je.length - 1; i++) {
      dJointID jid = dJointCreateHinge(World.world, cast(dJointGroupID) 0);
      dJointSetHingeParam(jid, dParamLoStop, -1);
      dJointSetHingeParam(jid, dParamHiStop, 1);
      dJointAttach(jid, je[i].bodyId, je[i + 1].bodyId);
      dJointSetHingeAnchor(jid,
                           (je[i].pos.x + je[i + 1].pos.x) / 2,
                           (je[i].pos.y + je[i + 1].pos.y) / 2,
                           (je[i].pos.z + je[i + 1].pos.z) / 2);
      dJointSetHingeAxis(jid, 0, 0, 1);
      dJointID[] joints = null;
      joints ~= jid;
      je[i].setJoints(joints);
    }
    for (int i = 0; i < je.length; i++) {
      Enemy pe = null, ne = null;
      if (i > 0)
        pe = je[i - 1];
      if (i < je.length - 1)
        ne = je[i + 1];
      je[i].setJointedEnemiesPrevNext(pe, ne);
      je[i].setJointedEnemies(je);
    }
    for (int i = 1; i < je.length; i++) {
      EnemyState s = je[i].getState();
      if (bodyBarrage)
        bodyBarrage.set(bullets, ship, s, cast(float) i / je.length / 2);
      s.forwardForceScale = forwardForceScale;
    }
    return je[0];
  }
}

/**
 * Centipede body specs.
 */
public class CentBodyToAndFrom: CentBody {
  public this(Field field, Ship ship, BulletPool bullets, World world, CentHead headSpec) {
    super(field, ship, bullets, world, headSpec);
  }

  public override void initState(Enemy enemy, EnemyState state) {
    state.type = CentType.TO_AND_FROM;
    super.initState(enemy, state);
    _colorR = CentHeadToAndFrom.COLOR_R;
    _colorG = CentHeadToAndFrom.COLOR_G;
    _colorB = CentHeadToAndFrom.COLOR_B;
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 1.0f);
  }
}

public class CentBodyChase: CentBody {
  public this(Field field, Ship ship, BulletPool bullets, World world, CentHead headSpec) {
    super(field, ship, bullets, world, headSpec);
  }

  public override void initState(Enemy enemy, EnemyState state) {
    state.type = CentType.CHASE;
    super.initState(enemy, state);
    _colorR = CentHeadChase.COLOR_R;
    _colorG = CentHeadChase.COLOR_G;
    _colorB = CentHeadChase.COLOR_B;
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 1.0f);
  }
}

public class CentBodyRoll: CentBody {
  public this(Field field, Ship ship, BulletPool bullets, World world, CentHead headSpec) {
    super(field, ship, bullets, world, headSpec);
  }

  public override void initState(Enemy enemy, EnemyState state) {
    state.type = CentType.ROLL;
    super.initState(enemy, state);
    _colorR = CentHeadRoll.COLOR_R;
    _colorG = CentHeadRoll.COLOR_G;
    _colorB = CentHeadRoll.COLOR_B;
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 1.0f);
  }
}

public class CentBody: EnemySpec, ConnectedParticlesBodyAddable {
  mixin CentMoveImpl;
 private:

  public this(Field field, Ship ship, BulletPool bullets, World world, CentHead headSpec) {
    this.field = field;
    this.ship = ship;
    this.bullets = bullets;
    this.world = world;
    this.headSpec = headSpec;
    shape = new ShapeGroup;
    shape.addShape(new Square(world, MASS, 0, 0, SIZE / 4, SIZE));
    subShape = new EyeShape;
  }

  public override void initState(Enemy enemy, EnemyState state) {
    super.initState(enemy, state);
    state.trgDeg = 0;
    state.turnCnt = 0;
    state.moveFlag = 0;
    state.destroyable = state.isHead = false;
  }
}

public interface ConnectedParticlesBodyAddable {
  void addConnectedParticlesBody(Enemy enemy, EnemyState state);
}

/**
 * Block spec.
 */
public class Block: EnemySpec {
 private:
  static const float SLOW_VELOCITY_RATIO = 0.022f;
  static const float SLOW_ANGULAR_RATIO = 0.022f;

  public this(Field field, Ship ship, BulletPool bullets, World world) {
    this.field = field;
    this.ship = ship;
    this.bullets = bullets;
    this.world = world;
    shape = new ShapeGroup;
    shape.addShape(new Box(world, 1, 0, 0, 0, 1, 1, 1));
    _rotate2d = false;
    _collideBullet = true;
  }

  public override void initState(Enemy enemy, EnemyState state) {
    super.initState(enemy, state);
    _colorR = 0;
    _colorG = 0;
    _colorB = 1;
    state.linePoint.setSpectrumParams(_colorR, _colorG, _colorB, 0.7f);
    state.type = -1;
  }

  public override bool move(Enemy enemy, EnemyState state) {
    if (field.checkInField(state.pos)) {
      enemy.slowLinearVel(SLOW_VELOCITY_RATIO * state.massScale);
      state.linePoint.enableSpectrumColor = true;
    } else {
      state.linePoint.enableSpectrumColor = false;
    }
    enemy.slowAngularVel(SLOW_ANGULAR_RATIO);
    enemy.addForce(0, 0, -Field.GRAVITY * 0.25f * state.massScale);
    return true;
  }

  public override void destroyed(Enemy enemy, EnemyState state) {
    float d = atan2(state.pos.x, -state.pos.y);
    for (int i = 0; i < 5; i++)
      enemy.addConnectedParticles(d + rand.nextSignedFloat(PI / 4), 4.0f * state.sizeScale.x);
    enemy.addScore(100, 0.3f);
  }
}
