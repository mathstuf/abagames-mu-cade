/*
 * $Id: bulletpool.d,v 1.2 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.bulletpool;

private import std.math;
private import derelict.opengl3.gl;
private import bml = bulletml.bulletml;
private import derelict.ode.ode;
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
  uint cnt;
  SimpleBulletPool simpleBullets;

  public this(int n, int sn, Object[] args) {
    super(n, args);
    Bullet.setBulletsManager(this);
    cnt = 0;
    simpleBullets = new SimpleBulletPool(sn, args);
    simpleBullets.init(cast(World) args[4]);
  }

  public void addBullet(Bullet parent, float deg, float speed) {
    BulletActor rb = (cast(BulletImpl) parent).rootBullet;
    if (rb)
      if (!rb.activated)
        return;
    BulletActor ba = cast(BulletActor) getInstance();
    if (!ba)
      return;
    BulletImpl nbi = ba.bullet;
    nbi.setParam(cast(BulletImpl) parent);
    if (nbi.gotoNextParser()) {
      bml.BulletMLRunner runner = bml.createRunner(nbi, nbi.getParser());
      ba.set(runner, parent.pos.x, parent.pos.y, deg, speed);
      ba.setMorphSeed();
    } else {
      SimpleBullet sb = simpleBullets.getInstance();
      if (!sb)
        return;
      sb.set(parent.pos.x, parent.pos.y, deg, speed * ba.bullet.getSpeedRank());
    }
  }

  public void addBullet(Bullet parent, const bml.ResolvedBulletML state, float deg, float speed) {
    BulletActor rb = (cast(BulletImpl) parent).rootBullet;
    if (rb)
      if (!rb.activated)
        return;
    BulletActor ba = cast(BulletActor) getInstance();
    if (!ba)
      return;
    BulletImpl nbi = ba.bullet;
    bml.BulletMLRunner runner = bml.createRunner(nbi, state);
    nbi.setParam(cast(BulletImpl) parent);
    ba.set(runner, parent.pos.x, parent.pos.y, deg, speed);
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
    bml.BulletMLRunner runner = bml.createRunner(nbi, nbi.getParser());
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

  public uint getTurn() {
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
}

extern (C) {
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
