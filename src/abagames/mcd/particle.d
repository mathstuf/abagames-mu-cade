/*
 * $Id: particle.d,v 1.3 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.particle;

private import std.math;
private import opengl;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.mcd.shape;
private import abagames.mcd.field;
private import abagames.mcd.screen;
private import abagames.mcd.ship;
private import abagames.mcd.letter;

/**
 * Particles.
 */
public class Particle: Actor {
 private:
  static Rand rand;
  Field field;
  Vector3 pos;
  Vector3 vel;
  float size;
  Vector3 size3;
  float deg;
  float md;
  int cnt;
  float r, g, b;
  float decayRatio;
  LinePoint linePoint;

  invariant {
    if (pos) {
      assert(pos.x <>= 0);
      assert(pos.y <>= 0);
      assert(pos.z <>= 0);
      assert(vel.x <>= 0);
      assert(vel.y <>= 0);
      assert(vel.z <>= 0);
      assert(deg <>= 0);
      assert(md <>= 0);
      assert(size > 0 && size < 10);
      assert(r >= 0 && r <= 1);
      assert(g >= 0 && g <= 1);
      assert(b >= 0 && b <= 1);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    pos = new Vector3;
    vel = new Vector3;
    size = 1;
    size3 = new Vector3;
    linePoint = new LinePoint(field);
    linePoint.setPos(new Vector3(0, 0, 0));
    deg = md = 0;
    r = g = b = 0;
  }

  public void set(Vector p,
                  float vx, float vy, float sz, float r, float g, float b,
                  int c = 60) {
    set(p.x, p.y, 0, vx, vy, 0, sz, r, g, b, c);
  }

  public void set(Vector3 p,
                  float vx, float vy, float sz, float r, float g, float b,
                  int c = 60) {
    set(p.x, p.y, p.z, vx, vy, 0, sz, r, g, b, c);
  }

  public void set(float x, float y,
                  float vx, float vy, float sz, float r, float g, float b,
                  int c = 60) {
    set(x, y, 0, vx, vy, 0, sz, r, g, b, c);
  }

  public void set(float x, float y, float z,
                  float vx, float vy, float vz, float sz, float r, float g, float b,
                  int c = 60) {
    pos.x = x;
    pos.y = y;
    pos.z = z;
    vel.x = vx;
    vel.y = vy;
    vel.z = vz;
    size = sz;
    deg = rand.nextFloat(PI * 2);
    md = rand.nextSignedFloat(0.3f);
    cnt = c + rand.nextInt(c);
    if (cnt < 4)
      cnt = 4;
    decayRatio = 1 - 0.02f * 60 / cnt;
    this.r = r;
    this.g = g;
    this.b = b;
    linePoint.setSpectrumParams(r, g, b, 1);
    linePoint.init();
    size3.x = size3.y = size3.z = size;
    linePoint.setSize(size3);
    _exists = true;
  }

  public override void move() {
    pos += vel;
    vel *= 0.98f;
    this.r *= decayRatio;
    this.g *= decayRatio;
    this.b *= decayRatio;
    linePoint.setSpectrumParams(r, g, b, 1);
    deg += md;
    recordLinePoints();
    cnt--;
    if (cnt <= 0)
      _exists = false;
  }

  private void recordLinePoints() {
    glPushMatrix();
    Screen.glTranslate(pos);
    glRotatef(deg * 180 / PI, 0, 0, 1);
    linePoint.beginRecord();
    linePoint.record(-1, 0, 0);
    linePoint.record( 1, 0, 0);
    linePoint.endRecord();
    glPopMatrix();
  }

  public override void draw() {
    linePoint.drawSpectrum();
    linePoint.drawWithSpectrumColor();
  }
}

public class ParticlePool: ActorPool!(Particle) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Particles connected with lines.
 */
public class ConnectedParticle: Actor {
  static const float SPRING_CONSTANT = 0.04f;
  static Rand rand;
  Field field;
  Vector3 _pos;
  Vector3 _vel;
  GLdouble rot[16];
  bool enableRotate;
  int cnt;
  float decayRatio;
  float r, g, b;
  float baseLength;
  ConnectedParticle prevParticle;
  LinePoint linePoint;

  invariant {
    if (_pos) {
      assert(_pos.x <>= 0);
      assert(_pos.y <>= 0);
      assert(_pos.z <>= 0);
      assert(_vel.x <>= 0);
      assert(_vel.y <>= 0);
      assert(_vel.z <>= 0);
      assert(r >= 0 && r <= 1);
      assert(g >= 0 && g <= 1);
      assert(b >= 0 && b <= 1);
      assert(baseLength <>= 0);
    }
    if (prevParticle && prevParticle._exists) {
      assert(prevParticle._pos.x <>= 0);
      assert(prevParticle._pos.y <>= 0);
      assert(prevParticle._pos.z <>= 0);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    _pos = new Vector3;
    _vel = new Vector3;
    linePoint = new LinePoint(field);
    linePoint.setPos(new Vector3(0, 0, 0));
    linePoint.setSize(new Vector3(1, 1, 1));
    r = g = b = 0;
    baseLength = 0;
  }

  public void set(float x, float y, float d, float s, float r, float g, float b,
                  int c, float bl = 0, ConnectedParticle pp = null, bool decay = true) {
    set(x, y, 0, d, s, r, g, b, c, bl, pp, decay);
  }

  public void set(float x, float y, float z, float d, float s, float r, float g, float b,
                  int c, float bl = 0, ConnectedParticle pp = null, bool decay = true) {
    _pos.x = x;
    _pos.y = y;
    _pos.z = z;
    _vel.x = -sin(d) * s;
    _vel.y = cos(d) * s;
    _vel.z = 0;
    enableRotate = false;
    cnt = c;
    if (cnt < 4)
      cnt = 4;
    if (decay)
      decayRatio = 1 - 0.07f * 60 / cnt;
    else
      decayRatio = 1 - 0.01f * 60 / cnt;
    this.r = r;
    this.g = g;
    this.b = b;
    baseLength = bl;
    prevParticle = pp;
    linePoint.setSpectrumParams(r, g, b, 1);
    linePoint.init();
    _exists = true;
  }

  public void setRot(GLdouble[16] r) {
    for (int i = 0; i < 16; i++)
      rot[i] = r[i];
    enableRotate = true;
  }

  public override void move() {
    _vel *= 0.96f;
    if (_vel.x > 2)
      _vel.x = 2;
    else if (_vel.x < -2)
      _vel.x = -2;
    if (_vel.y > 2)
      _vel.y = 2;
    else if (_vel.y < -2)
      _vel.y = -2;
    _pos += _vel;
    this.r *= decayRatio;
    this.g *= decayRatio;
    this.b *= decayRatio;
    linePoint.setSpectrumParams(r, g, b, 1);
    if (prevParticle && prevParticle.exists) {
      float ds = pos.dist(prevParticle.pos);
      float lo = ds - baseLength;
      if (lo > 0.01f && ds > 0.01f) {
        float d = atan2(prevParticle.pos.x - pos.x, prevParticle.pos.y - pos.y);
        float ax = sin(d) * lo * SPRING_CONSTANT;
        float ay = cos(d) * lo * SPRING_CONSTANT;
        _vel.x += ax;
        _vel.y += ay;
        prevParticle.vel.x -= ax;
        prevParticle.vel.y -= ay;
      }
    }
    cnt--;
    if (cnt <= 0)
      _exists = false;
  }

  public void recordLinePoints() {
    if (!prevParticle || !prevParticle.exists)
      return;
    glPushMatrix();
    Screen.glTranslate(_pos);
    if (enableRotate)
      glMultMatrixd(rot);
    linePoint.beginRecord();
    linePoint.record(0, 0, 0);
    linePoint.record((prevParticle.pos.x - _pos.x) * 2,
                     (prevParticle.pos.y - _pos.y) * 2,
                     (prevParticle.pos.z - _pos.z) * 2);
    linePoint.endRecord();
    glPopMatrix();
  }

  public override void draw() {
    if (!prevParticle || !prevParticle.exists)
      return;
    linePoint.drawSpectrum();
    linePoint.drawWithSpectrumColor();
    glPushMatrix();
    Screen.glTranslate(_pos);
    Screen.setColor(r, g, b);
    glBegin(GL_LINES);
    glVertex3f(0, 0, 0);
    glVertex3f(prevParticle.pos.x - _pos.x,
               prevParticle.pos.y - _pos.y,
               prevParticle.pos.z - _pos.z);
    glEnd();
    glPopMatrix();
  }

  public Vector3 pos() {
    return _pos;
  }

  public Vector3 vel() {
    return _vel;
  }
}

public class ConnectedParticlePool: ActorPool!(ConnectedParticle) {
  public this(int n, Object[] args) {
    super(n, args);
  }

  public void recordLinePoints() {
    foreach (ConnectedParticle cp; actor)
      if (cp.exists)
        cp.recordLinePoints();
  }
}

/**
 * Flying tail parts.
 */
public class TailParticle: Actor {
 public:
  static const int COUNT = 60;
 private:
  static const float SIZE = 1;
  static Rand rand;
  static Vector3 trgPos;
  static float trgDeg;
  Field field;
  Ship ship;
  Vector3 pos;
  Vector3 vel;
  float size;
  Vector3 size3;
  float deg;
  float md;
  int cnt;
  float r, g, b;
  ShapeGroup shape;
  LinePoint linePoint;

  invariant {
    if (pos) {
      assert(pos.x <>= 0);
      assert(pos.y <>= 0);
      assert(pos.z <>= 0);
      assert(vel.x <>= 0);
      assert(vel.y <>= 0);
      assert(vel.z <>= 0);
      assert(size > 0 && size < 10);
      assert(deg <>= 0);
      assert(r >= 0 && r <= 1);
      assert(g >= 0 && g <= 1);
      assert(b >= 0 && b <= 1);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void setTarget(Vector3 p, float d) {
    trgPos = p;
    trgDeg = d;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    ship = cast(Ship) args[1];
    pos = new Vector3;
    vel = new Vector3;
    deg = 0;
    size = 1;
    size3 = new Vector3;
    shape = new ShapeGroup;
    shape.addShape(new Square(null, 0, 0, 0, SIZE * ShipTail.WIDTH, SIZE));
    linePoint = new LinePoint(field);
    r = g = b = 0;
  }

  public void set(float x, float y, float z, float sz, float r, float g, float b, int c) {
    pos.x = x;
    pos.y = y;
    pos.z = z;
    vel.x = rand.nextSignedFloat(0.3f);
    vel.y = 0.3f;
    vel.z = 0;
    size = sz;
    deg = rand.nextFloat(PI * 2);
    md = rand.nextSignedFloat(0.3f);
    cnt = c;
    this.r = r;
    this.g = g;
    this.b = b;
    linePoint.setSpectrumParams(r, g, b, 0.5f);
    linePoint.init();
    size3.x = size3.y = size3.z = size;
    linePoint.setSize(size3);
    _exists = true;
  }

  public override void move() {
    pos += vel;
    float vr = 1.0f - cast(float) cnt / COUNT;
    vr *= 0.25f;
    vel.x += (trgPos.x - pos.x) * 0.002f;
    vel.y += (trgPos.y - pos.y) * 0.002f;
    vel.z += (trgPos.z - pos.z) * 0.002f;
    vel *= 0.98f;
    pos.x += (trgPos.x - pos.x) * vr;
    pos.y += (trgPos.y - pos.y) * vr;
    pos.z += (trgPos.z - pos.z) * vr;
    r += (ShipTail.COLOR_R - r) * 0.03f;
    g += (ShipTail.COLOR_G - g) * 0.03f;
    b += (ShipTail.COLOR_B - b) * 0.03f;
    linePoint.setSpectrumParams(r, g, b, 0.5f);
    deg += md;
    md *= 0.9f;
    float od = trgDeg - deg;
    Math.normalizeDeg(od);
    deg += od * vr;
    recordLinePoints();
    cnt--;
    if (cnt <= 0) {
      ship.addTail(size);
      _exists = false;
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

  public override void draw() {
    linePoint.drawSpectrum();
    linePoint.drawWithSpectrumColor();
  }
}

public class TailParticlePool: ActorPool!(TailParticle) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Stars.
 */
public class StarParticle: Actor {
 private:
  Field field;
  Vector3 pos;
  Vector3 vel;
  float size;
  int cnt;

  invariant {
    if (pos) {
      assert(pos.x <>= 0);
      assert(pos.y <>= 0);
      assert(pos.z <>= 0);
      assert(vel.x <>= 0);
      assert(vel.y <>= 0);
      assert(vel.z <>= 0);
      assert(size > 0 && size < 10);
    }
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    pos = new Vector3;
    vel = new Vector3;
    size = 1;
  }

  public void set(float x, float y, float z, float speed, float sz) {
    pos.x = x;
    pos.y = y;
    pos.z = z;
    vel.x = 0;
    vel.y = 0;
    vel.z = -speed;
    size = sz;
    _exists = true;
  }

  public override void move() {
    pos += vel;
    if (pos.z < -100)
      _exists = false;
  }

  public override void draw() {
    glVertex3f(pos.x, pos.y, pos.z);
    glVertex3f(pos.x, pos.y, pos.z + size);
  }
}

public class StarParticlePool: ActorPool!(StarParticle) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Number indicator that shows a score and a multiplier.
 */
public class NumIndicator: Actor {
 private:
  Vector pos;
  Vector vel;
  float size, trgSize;
  int cnt;
  int num1, num2;

  invariant {
    if (pos) {
      assert(pos.x <>= 0);
      assert(pos.y <>= 0);
      assert(vel.x <>= 0);
      assert(vel.y <>= 0);
      assert(size > 0 && size < 10);
    }
  }

  public override void init(Object[] args) {
    pos = new Vector;
    vel = new Vector;
    size = 1;
    num1 = 0;
    num2 = -1;
  }

  public void set(int n1, int n2, float x, float y, float vx, float vy, float sz = 0.5f, int c = 300) {
    num1 = n1;
    num2 = n2;
    pos.x = x;
    pos.y = y;
    vel.x = vx;
    vel.y = vy;
    size = 0.1f;
    trgSize = sz;
    cnt = c;
    _exists = true;
  }

  public override void move() {
    pos += vel;
    size += (trgSize - size) * 0.05f;
    cnt--;
    if (cnt <= 0)
      _exists = false;
  }

  public override void draw() {
    if (num2 <= 1) {
      Letter.drawNumSign(num1, pos.x + Letter.getWidthNum(num1, size) / 2, pos.y, size);
    } else {
      float wd = Letter.getWidthNum(num1, size) + Letter.getWidth(1, size) + Letter.getWidthNum(num2, size);
      float x;
      x = pos.x - wd / 2 + Letter.getWidthNum(num1, size);
      Letter.drawNumSign(num1, x, pos.y, size);
      x = pos.x + wd / 2;
      Letter.drawNumSign(num2, x, pos.y, size, 33);
    }
  }
}

public class NumIndicatorPool: ActorPool!(NumIndicator) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
