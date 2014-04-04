/*
 * $Id: bullet.d,v 1.2 2006/02/22 22:27:46 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.bullet;

private import std.math;
private import std.string;
private import opengl;
private import bulletml;
private import ode.ode;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.bulletml.bullet;
private import abagames.util.ode.world;
private import abagames.util.ode.odeactor;
private import abagames.mcd.bulletimpl;
private import abagames.mcd.bulletpool;
private import abagames.mcd.field;
private import abagames.mcd.screen;
private import abagames.mcd.enemy;
private import abagames.mcd.shape;
private import abagames.mcd.ship;
private import abagames.mcd.gamemanager;
private import abagames.mcd.particle;
private import abagames.mcd.soundmanager;

/**
 * Enemy's bullet (controlled by BulletML).
 */
public class BulletActor: Actor {
 public:
  BulletImpl bullet;
  bool activated;
 private:
  static const float SIZE = 0.8f;
  static int idCnt = 0;
  Field field;
  Ship ship;
  GameManager gameManager;
  int cnt;
  bool isTop;
  bool isAimTop;
  bool isVisible;
  bool shouldBeRemoved;
  bool isWait;
  int postWait;  // Waiting count before a top(root) bullet rewinds the action.
  int waitCnt;
  bool isMorphSeed;  // Bullet marked as morph seed disappears after it morphs.
  ShapeGroup shape;
  LinePoint linePoint;

  invariant {
    if (bullet && bullet.pos) {
      assert(bullet.pos.x <>= 0);
      assert(bullet.pos.y <>= 0);
      assert(bullet.deg <>= 0);
    }
    assert(cnt >= 0);
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    ship = cast(Ship) args[1];
    gameManager = cast(GameManager) args[2];
    cnt = 0;
    bullet = new BulletImpl(idCnt);
    idCnt++;
    shape = new ShapeGroup;
    shape.addShape(new Square(null, 0, 0, 0, SIZE * 0.5f, SIZE));
    linePoint = new LinePoint(field);
    linePoint.setSpectrumParams(1, 0.25f, 0.5f, 0.2f);
  }

  public void set(BulletMLRunner* runner,
                  float x, float y, float deg, float speed) {
    bullet.set(runner, x, y, deg, speed, 0);
    start();
  }

  protected void start() {
    isTop = isAimTop = false;
    isWait = false;
    isVisible = true;
    isMorphSeed = false;
    activated = true;
    cnt = 0;
    shouldBeRemoved = false;
    linePoint.init();
    exists = true;
  }

  public void setInvisible() {
    isVisible = false;
  }

  public void setTop() {
    isTop = isAimTop = true;
    setInvisible();
  }

  public void unsetTop() {
    isTop = isAimTop = false;
  }

  public void unsetAimTop() {
    isAimTop = false;
  }

  public void setWait(int prvw, int pstw) {
    isWait = true;
    waitCnt = prvw;
    postWait = pstw;
  }

  public void setMorphSeed() {
    isMorphSeed = true;
  }

  public void rewind() {
    bullet.resetParser();
    BulletMLRunner *runner = BulletMLRunner_new_parser(bullet.getParser());
    BulletPool.registFunctions(runner);
    bullet.setRunner(runner);
  }

  public void remove() {
    shouldBeRemoved = true;
  }

  public void removeForced() {
    bullet.remove();
    exists = false;
  }

  public override void move() {
    Vector tpos = bullet.target.getTargetPos();
    Bullet.target.x = tpos.x;
    Bullet.target.y = tpos.y;
    if (isAimTop) {
      float ox = tpos.x - bullet.pos.x;
      bullet.deg = (atan2(-ox, tpos.y - bullet.pos.y) * bullet.xReverse
		    + PI / 2) * bullet.yReverse - PI / 2;
    }
    if (isWait && waitCnt > 0) {
      waitCnt--;
      if (shouldBeRemoved)
        removeForced();
      return;
    }
    bullet.move();
    if (bullet.isEnd()) {
      if (isTop) {
        rewind();
        if (isWait) {
          waitCnt = postWait;
          return;
        }
      } else if (isMorphSeed) {
        removeForced();
        return;
      }
    }
    if (shouldBeRemoved) {
      removeForced();
      return;
    }
    float mx =
      (-sin(bullet.deg) * bullet.speed + bullet.acc.x) *
        bullet.getSpeedRank() * bullet.xReverse;
    float my =
      (cos(bullet.deg) * bullet.speed - bullet.acc.y) *
        bullet.getSpeedRank() * bullet.yReverse;
    bullet.pos.x += mx;
    bullet.pos.y += my;
    if (isVisible) {
      if (!field.checkInField(bullet.pos))
        removeForced();
    }
    cnt++;
    if (!isTop && cnt > 600)
      removeForced();
  }

  public void draw() {
  }

  public void slowdown() {
    bullet.slowdown();
    postWait *= 2;
  }
}

/**
 * Enemy's bullet (moving straight ahead).
 */
public class SimpleBullet: OdeActor {
 private:
  static const float SIZE = 0.8f;
  static const float MASS = 500;
  static const float FORCE = 200000;
  static Rand rand;
  Field field;
  Ship ship;
  GameManager gameManager;
  ParticlePool particles;
  Vector pos;
  Vector firstForce;
  float deg;
  float speed;
  int removeCnt;
  ShapeGroup shape;
  LinePoint linePoint;
  int cnt;

  invariant {
    if (pos) {
      assert(pos.x <>= 0);
      assert(pos.y <>= 0);
      assert(deg <>= 0);
      assert(speed > 0 && speed < 10);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void init(Object[] args) {
    super.init();
    field = cast(Field) args[0];
    ship = cast(Ship) args[1];
    gameManager = cast(GameManager) args[2];
    particles = cast(ParticlePool) args[3];
    pos = new Vector;
    deg = 0;
    speed = 1;
    firstForce = new Vector;
    shape = new ShapeGroup;
    shape.addShape(new Square(world, MASS, 0, 0, SIZE * 0.5f, SIZE));
    linePoint = new LinePoint(field);
    linePoint.setSpectrumParams(1, 0.25f, 0.5f, 0.2f);
  }

  public void set(float x, float y, float d, float sp) {
    super.set();
    pos.x = x;
    pos.y = y;
    dBodySetPosition(_bodyId, x, y, 0);
    deg = d;
    setDeg(d);
    speed = sp;
    shape.setMass(this);
    shape.setGeom(this, cast(dSpaceID) 0);
    firstForce.x = -sin(d) * sp * FORCE;
    firstForce.y = cos(d) * sp * FORCE;
    addForce(firstForce.x, firstForce.y);
    removeCnt = 0;
    cnt = 0;
    linePoint.init();
  }

  public override void move() {
    dReal *p = dBodyGetPosition(_bodyId);
    pos.x = p[0];
    pos.y = p[1];
    dBodySetPosition(_bodyId, pos.x, pos.y, 0);
    if (removeCnt > 0) {
      removeCnt++;
      if (removeCnt > 5) {
        remove();
        return;
      }
    }
    if (!field.checkInField(pos)) {
      remove();
      return;
    }
    recordLinePoints();
    doCollide();
    cnt++;
    if (cnt > 300) {
      remove();
      return;
    }
    dReal* lv = getLinearVel();
    if (fabs(lv[0]) + fabs(lv[1]) < 1) {
      remove();
      return;
    }
  }

  public override void collide(OdeActor actor, inout bool hasCollision, inout bool checkFeedback) {
    hasCollision = checkFeedback = false;
    Enemy e = cast(Enemy) actor;
    if (cast(Ship) actor || cast(ShipTail) actor || (e && e.collideBullet)) {
      if (removeCnt <= 0) {
        removeCnt = 1;
        for (int i = 0; i < 5; i++) {
          Particle p = particles.getInstanceForced();
          float d = deg + PI + rand.nextSignedFloat(0.5f);
          float v = speed * (0.5f + rand.nextFloat(0.5f));
          p.set(pos, -sin(d) * v, cos(d) * v, 0.2f + rand.nextFloat(0.2f),
                1, 0.5f, 0.5f);
        }
        if (cast(Ship) actor || cast(ShipTail) actor) {
          gameManager.addScore(10);
          SoundManager.playSe("bullethit.wav");
        }
      }
      hasCollision = true;
      return;
    }
  }

  private void recordLinePoints() {
    glPushMatrix();
    Screen.glTranslate(pos);
    glRotatef(deg * 180 / PI, 0, 0, 1);
    linePoint.beginRecord();
    shape.recordLinePoints(linePoint);
    linePoint.endRecord();
    glPopMatrix();
  }

  public void collapseIntoParticle() {
    Particle p = particles.getInstanceForced();
    float d = deg;
    float v = speed;
    p.set(pos, -sin(d) * v, cos(d) * v, 0.2f, 0.9f, 0.6f, 0.3f);
    remove();
    if (!ship.inRestartBulletDisap)
      gameManager.addScore(10);
  }

  public void drawSpectrum() {
    if (removeCnt > 0)
      return;
    linePoint.drawSpectrum();
  }

  public void drawShadow() {
    if (removeCnt > 0)
      return;
    shape.drawShadow(linePoint);
  }

  public void draw() {
    if (removeCnt > 0)
      return;
    linePoint.draw();
  }

  public void slowdown() {
    if (removeCnt > 0)
      return;
    addForce(-firstForce.x / 2, -firstForce.y / 2);
  }
}
