/*
 * $Id: bulletpool.d,v 1.2 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.bulletpool;

private import std.math;
private import opengl;
private import bulletml;
private import ode.ode;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.bulletml.bullet;
private import abagames.util.bulletml.bulletsmanager;
private import abagames.util.ode.world;
private import abagames.util.ode.odeactor;
private import abagames.mcd.bullet;
private import abagames.mcd.bulletimpl;
private import abagames.mcd.bullettarget;

/**
 * Bullet actor pool that works as BulletsManager.
 */
public class BulletPool: ActorPool!(BulletActor), BulletsManager {
 private:
  int cnt;
  SimpleBulletPool simpleBullets;

  public this(int n, int sn, Object[] args) {
    super(n, args);
    Bullet.setBulletsManager(this);
    cnt = 0;
    simpleBullets = new SimpleBulletPool(sn, args);
    simpleBullets.init(cast(World) args[4]);
  }

  public void addBullet(float deg, float speed) {
    BulletActor rb = (cast(BulletImpl) Bullet.now).rootBullet;
    if (rb)
      if (!rb.activated)
        return;
    BulletActor ba = cast(BulletActor) getInstance();
    if (!ba)
      return;
    BulletImpl nbi = ba.bullet;
    nbi.setParam(cast(BulletImpl) Bullet.now);
    if (nbi.gotoNextParser()) {
      BulletMLRunner *runner = BulletMLRunner_new_parser(nbi.getParser());
      BulletPool.registFunctions(runner);
      ba.set(runner, Bullet.now.pos.x, Bullet.now.pos.y, deg, speed);
      ba.setMorphSeed();
    } else {
      SimpleBullet sb = simpleBullets.getInstance();
      if (!sb)
        return;
      sb.set(Bullet.now.pos.x, Bullet.now.pos.y, deg, speed * ba.bullet.getSpeedRank());
    }
  }

  public void addBullet(BulletMLState *state, float deg, float speed) {
    BulletActor rb = (cast(BulletImpl) Bullet.now).rootBullet;
    if (rb)
      if (!rb.activated)
        return;
    BulletActor ba = cast(BulletActor) getInstance();
    if (!ba)
      return;
    BulletMLRunner* runner = BulletMLRunner_new_state(state);
    registFunctions(runner);
    BulletImpl nbi = ba.bullet;
    nbi.setParam(cast(BulletImpl) Bullet.now);
    ba.set(runner, Bullet.now.pos.x, Bullet.now.pos.y, deg, speed);
  }

  public BulletActor addTopBullet(ParserParam[] parserParam,
                                  float x, float y, float deg, float speed,
                                  float xReverse, float yReverse,
                                  BulletTarget target,
                                  int prevWait, int postWait) {
    BulletActor ba = getInstance();
    if (!ba)
      return null;
    BulletImpl nbi = ba.bullet;
    nbi.setParamFirst(parserParam, xReverse, yReverse, target, ba);
    BulletMLRunner *runner = BulletMLRunner_new_parser(nbi.getParser());
    BulletPool.registFunctions(runner);
    ba.set(runner, x, y, deg, speed);
    ba.setWait(prevWait, postWait);
    ba.setTop();
    return ba;
  }

  public override void move() {
    simpleBullets.move();
    super.move();
    cnt++;
  }

  public void drawShadow() {
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    simpleBullets.drawShadow();
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
  }

  public void drawSpectrum() {
    simpleBullets.drawSpectrum();
  }

  public override void draw() {
    simpleBullets.draw();
  }

  public int getTurn() {
    return cnt;
  }

  public void killMe(Bullet bullet) {
    assert((cast(BulletActor) actor[bullet.id]).bullet.id == bullet.id);
    (cast(BulletActor) actor[bullet.id]).remove();
  }

  public override void clear() {
    foreach (BulletActor ba; actor)
      if (ba.exists)
        ba.removeForced();
    actorIdx = 0;
    cnt = 0;
    simpleBullets.clear();
  }

  public int collapseIntoParticle() {
    return simpleBullets.collapseIntoParticle();
  }

  public void slowdown() {
    simpleBullets.slowdown();
  }

  public static void registFunctions(BulletMLRunner* runner) {
    BulletMLRunner_set_getBulletDirection(runner, &getBulletDirection_);
    BulletMLRunner_set_getAimDirection(runner, &getAimDirectionWithRev_);
    BulletMLRunner_set_getBulletSpeed(runner, &getBulletSpeed_);
    BulletMLRunner_set_getDefaultSpeed(runner, &getDefaultSpeed_);
    BulletMLRunner_set_getRank(runner, &getRank_);
    BulletMLRunner_set_createSimpleBullet(runner, &createSimpleBullet_);
    BulletMLRunner_set_createBullet(runner, &createBullet_);
    BulletMLRunner_set_getTurn(runner, &getTurn_);
    BulletMLRunner_set_doVanish(runner, &doVanish_);

    BulletMLRunner_set_doChangeDirection(runner, &doChangeDirection_);
    BulletMLRunner_set_doChangeSpeed(runner, &doChangeSpeed_);
    BulletMLRunner_set_doAccelX(runner, &doAccelX_);
    BulletMLRunner_set_doAccelY(runner, &doAccelY_);
    BulletMLRunner_set_getBulletSpeedX(runner, &getBulletSpeedX_);
    BulletMLRunner_set_getBulletSpeedY(runner, &getBulletSpeedY_);
    BulletMLRunner_set_getRand(runner, &getRand_);
  }
}

extern (C) {
  double getAimDirectionWithRev_(BulletMLRunner* r) {
    Vector b = Bullet.now.pos;
    Vector t = Bullet.target;
    float xrev = (cast(BulletImpl) Bullet.now).xReverse;
    float yrev = (cast(BulletImpl) Bullet.now).yReverse;
    float ox = t.x - b.x;
    return rtod((atan2(-ox, t.y - b.y) * xrev + PI / 2) * yrev - PI / 2);
  }
}

public class SimpleBulletPool: OdeActorPool!(SimpleBullet) {
  public this(int n, Object[] args) {
    super(n, args);
  }

  public void drawShadow() {
    foreach (SimpleBullet sb; actor)
      if (sb.exists)
        sb.drawShadow();
  }

  public void drawSpectrum() {
    foreach (SimpleBullet sb; actor)
      if (sb.exists)
        sb.drawSpectrum();
  }

  public override void clear() {
    foreach (SimpleBullet sb; actor)
      if (sb.exists)
        sb.remove();
    actorIdx = 0;
  }

  public int collapseIntoParticle() {
    int c = 0;
    foreach (SimpleBullet sb; actor) {
      if (sb.exists) {
        sb.collapseIntoParticle();
        c++;
      }
    }
    return c;
  }

  public void slowdown() {
    foreach (SimpleBullet sb; actor)
      if (sb.exists)
        sb.slowdown();
  }
}
