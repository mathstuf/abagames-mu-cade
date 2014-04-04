/*
 * $Id: shot.d,v 1.2 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.shot;

private import std.math;
private import std.string;
private import opengl;
private import ode.ode;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.ode.world;
private import abagames.util.ode.odeactor;
private import abagames.mcd.field;
private import abagames.mcd.screen;
private import abagames.mcd.enemy;
private import abagames.mcd.shape;
private import abagames.mcd.particle;
private import abagames.mcd.ship;
private import abagames.mcd.soundmanager;

/**
 * Player's shot.
 */
public template ShotImpl() {
 protected:
  Field field;
  ParticlePool particles;
  Vector pos;
  int cnt;
  int removeCnt;
  float _deg;
  ShapeGroup shape;
  LinePoint linePoint;

  invariant {
    if (pos) {
      assert(pos.x <>= 0);
      assert(pos.y <>= 0);
      assert(_deg <>= 0);
    }
    assert(cnt >= 0);
  }

  public void set(Vector3 p, float d) {
    super.set();
    pos.x = p.x - sin(d) * 0.5f;
    pos.y = p.y + cos(d) * 0.5f;
    dBodySetPosition(_bodyId, pos.x, pos.y, 0);
    _deg = d;
    setDeg(d);
    shape.setMass(this);
    shape.setGeom(this, cast(dSpaceID) 0);
    addForce(-sin(d) * FORCE, cos(d) * FORCE);
    cnt = 0;
    removeCnt = 0;
    linePoint.init();
  }

  public override void move() {
    cnt++;
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
  }

  public override void collide(OdeActor actor, inout bool hasCollision, inout bool checkFeedback) {
    hasCollision = checkFeedback = false;
    Enemy e = cast(Enemy) actor;
    if (e) {
      if (removeCnt <= 0) {
        removeCnt = 1;
        for (int i = 0; i < 3; i++) {
          Particle p = particles.getInstanceForced();
          float d = deg + PI + rand.nextSignedFloat(0.4f);
          float v = 0.2f + rand.nextFloat(0.2f);
          p.set(pos, -sin(d) * v, cos(d) * v, 0.15f + rand.nextFloat(0.15f),
                0.5f, 1, 0);
        }
        SoundManager.playSe("hit.wav");
      }
      hasCollision = true;
    }
  }

  public void recordLinePoints() {
    glPushMatrix();
    Screen.glTranslate(pos);
    glRotatef(_deg * 180 / PI, 0, 0, 1);
    linePoint.beginRecord();
    shape.recordLinePoints(linePoint);
    linePoint.endRecord();
    glPopMatrix();
  }

  public override void draw() {
    if (removeCnt > 0)
      return;
    linePoint.drawSpectrum();
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    shape.drawShadow(linePoint);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    linePoint.draw();
  }

  public float deg() {
    return _deg;
  }
}

public class Shot: OdeActor {
  mixin ShotImpl;
 private:
  static const float FORCE = 3000;
  static const float SIZE = 1.2f;
  static const float MASS = 20;
  static Rand rand;

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void init(Object[] args) {
    super.init();
    field = cast(Field) args[0];
    particles = cast(ParticlePool) args[1];
    pos = new Vector;
    _deg = 0;
    cnt = 0;
    shape = new ShapeGroup;
    shape.addShape(new Square(world, MASS, 0, 0, SIZE * 0.2f, SIZE));
    linePoint = new LinePoint(field);
    linePoint.setSpectrumParams(0.2f, 0.4f, 0, 0.8f);
    linePoint.alpha = 0.5f;
  }
}

public class ShotPool: OdeActorPool!(Shot) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

public class EnhancedShot: OdeActor {
  mixin ShotImpl;
 private:
  static const float FORCE = 10000;
  static const float SIZE = 2;
  static const float MASS = 50;
  static Rand rand;

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void init(Object[] args) {
    super.init();
    field = cast(Field) args[0];
    particles = cast(ParticlePool) args[1];
    pos = new Vector;
    _deg = 0;
    cnt = 0;
    shape = new ShapeGroup;
    shape.addShape(new Triangle(world, MASS, 0, 0, SIZE * 0.33f, SIZE));
    linePoint = new LinePoint(field);
    linePoint.setSpectrumParams(0.9f, 0.6f, 0.3f, 0.75f);
  }
}

public class EnhancedShotPool: OdeActorPool!(EnhancedShot) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
