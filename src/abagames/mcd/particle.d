/*
 * $Id: particle.d,v 1.3 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.particle;

private import std.math;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
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
  vec3 pos;
  vec3 vel;
  float size;
  vec3 size3;
  float deg;
  float md;
  int cnt;
  float r, g, b;
  float decayRatio;
  LinePoint linePoint;

  invariant() {
    if (pos) {
      assert(!pos.x.isNaN);
      assert(!pos.y.isNaN);
      assert(!pos.z.isNaN);
      assert(!vel.x.isNaN);
      assert(!vel.y.isNaN);
      assert(!vel.z.isNaN);
      assert(!deg.isNaN);
      assert(!md.isNaN);
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
    pos = vec3(0);
    vel = vec3(0);
    size = 1;
    size3 = vec3(0);
    linePoint = new LinePoint(field);
    linePoint.setPos(vec3(0, 0, 0));
    deg = md = 0;
    r = g = b = 0;
  }

  public override void close() {
  }

  public void set(vec2 p,
                  float vx, float vy, float sz, float r, float g, float b,
                  int c = 60) nothrow {
    set(p.x, p.y, 0, vx, vy, 0, sz, r, g, b, c);
  }

  public void set(vec3 p,
                  float vx, float vy, float sz, float r, float g, float b,
                  int c = 60) nothrow {
    set(p.x, p.y, p.z, vx, vy, 0, sz, r, g, b, c);
  }

  public void set(float x, float y,
                  float vx, float vy, float sz, float r, float g, float b,
                  int c = 60) nothrow {
    set(x, y, 0, vx, vy, 0, sz, r, g, b, c);
  }

  public void set(float x, float y, float z,
                  float vx, float vy, float vz, float sz, float r, float g, float b,
                  int c = 60) nothrow {
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
    mat4 model = mat4.identity;
    model.rotate(-deg, vec3(0, 0, 1));
    model.translate(pos.x, pos.y, pos.z);

    linePoint.beginRecord(model);
    linePoint.record(-1, 0, 0);
    linePoint.record( 1, 0, 0);
    linePoint.endRecord();
  }

  public override void draw(mat4 view) {
    linePoint.drawSpectrum(view);
    linePoint.drawWithSpectrumColor(view);
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
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  Field field;
  vec3 _pos;
  vec3 _vel;
  mat4 rot;
  bool enableRotate;
  int cnt;
  float decayRatio;
  float r, g, b;
  float baseLength;
  ConnectedParticle prevParticle;
  LinePoint linePoint;

  invariant() {
    if (_pos) {
      assert(!_pos.x.isNaN);
      assert(!_pos.y.isNaN);
      assert(!_pos.z.isNaN);
      assert(!_vel.x.isNaN);
      assert(!_vel.y.isNaN);
      assert(!_vel.z.isNaN);
      assert(r >= 0 && r <= 1);
      assert(g >= 0 && g <= 1);
      assert(b >= 0 && b <= 1);
      assert(!baseLength.isNaN);
    }
    if (prevParticle && prevParticle._exists) {
      assert(!prevParticle._pos.x.isNaN);
      assert(!prevParticle._pos.y.isNaN);
      assert(!prevParticle._pos.z.isNaN);
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
    _pos = vec3(0);
    _vel = vec3(0);
    linePoint = new LinePoint(field);
    linePoint.setPos(vec3(0, 0, 0));
    linePoint.setSize(vec3(1, 1, 1));
    r = g = b = 0;
    baseLength = 0;

    if (program !is null) {
      return;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec3 pos;\n"
      "uniform vec3 prevPos;\n"
      "\n"
      "attribute float usePrev;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4((usePrev == 0.) ? prevPos : pos, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform vec3 color;\n"
      "uniform float brightness;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    GLint usePrevLoc = 0;
    program.bindAttribLocation(usePrevLoc, "usePrev");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] USEPREV = [
      0,
      1
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, USEPREV.length * float.sizeof, USEPREV.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(usePrevLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(usePrevLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
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

  public void setRot(mat4 r) {
    rot = r;
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
      float ds = pos.fastdist(prevParticle.pos);
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

    mat4 model = mat4.identity;
    if (enableRotate)
      model = model * rot;
    model.translate(_pos.x, _pos.y, _pos.z);

    linePoint.beginRecord(model);
    linePoint.record(0, 0, 0);
    linePoint.record((prevParticle.pos.x - _pos.x) * 2,
                     (prevParticle.pos.y - _pos.y) * 2,
                     (prevParticle.pos.z - _pos.z) * 2);
    linePoint.endRecord();
  }

  public override void draw(mat4 view) {
    if (!prevParticle || !prevParticle.exists)
      return;
    linePoint.drawSpectrum(view);
    linePoint.drawWithSpectrumColor(view);

    program.use();

    program.setUniform("projmat", view);
    program.setUniform("pos", _pos);
    program.setUniform("prevPos", prevParticle.pos);
    program.setUniform("color", r, g, b);
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao);
    glDrawArrays(GL_LINES, 0, 2);

    glBindVertexArray(0);
  }

  public vec3 pos() {
    return _pos;
  }

  public vec3 vel() {
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
  static vec3 trgPos;
  static float trgDeg;
  Field field;
  Ship ship;
  vec3 pos;
  vec3 vel;
  float size;
  vec3 size3;
  float deg;
  float md;
  int cnt;
  float r, g, b;
  ShapeGroup shape;
  LinePoint linePoint;

  invariant() {
    if (pos) {
      assert(!pos.x.isNaN);
      assert(!pos.y.isNaN);
      assert(!pos.z.isNaN);
      assert(!vel.x.isNaN);
      assert(!vel.y.isNaN);
      assert(!vel.z.isNaN);
      assert(size > 0 && size < 10);
      assert(!deg.isNaN);
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

  public static void setTarget(vec3 p, float d) {
    trgPos = p;
    trgDeg = d;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    ship = cast(Ship) args[1];
    pos = vec3(0);
    vel = vec3(0);
    deg = 0;
    size = 1;
    size3 = vec3(0);
    shape = new ShapeGroup;
    shape.addShape(new Square(null, 0, 0, 0, SIZE * ShipTail.WIDTH, SIZE));
    linePoint = new LinePoint(field);
    r = g = b = 0;
  }

  public override void close() {
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
    mat4 model = mat4.identity;
    model.rotate(-deg, vec3(0, 0, 1));
    model.translate(pos.x, pos.y, pos.z);

    linePoint.beginRecord(model);
    shape.recordLinePoints(linePoint);
    linePoint.endRecord();
  }

  public override void draw(mat4 view) {
    linePoint.drawSpectrum(view);
    linePoint.drawWithSpectrumColor(view);
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
  vec3 pos;
  vec3 vel;
  float size;
  int cnt;
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;

  invariant() {
    if (pos) {
      assert(!pos.x.isNaN);
      assert(!pos.y.isNaN);
      assert(!pos.z.isNaN);
      assert(!vel.x.isNaN);
      assert(!vel.y.isNaN);
      assert(!vel.z.isNaN);
      assert(size > 0 && size < 10);
    }
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    pos = vec3(0);
    vel = vec3(0);
    size = 1;

    if (program !is null) {
      return;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec3 pos;\n"
      "uniform float size;\n"
      "\n"
      "attribute float sizeFactor;\n"
      "\n"
      "void main() {\n"
      "  vec3 spos = pos;\n"
      "  spos.z += size * sizeFactor;\n"
      "  gl_Position = projmat * vec4(spos, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform vec4 color;\n"
      "uniform float brightness;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = color * vec4(vec3(brightness), 1);\n"
      "}\n"
    );
    GLint sizeFactorLoc = 0;
    program.bindAttribLocation(sizeFactorLoc, "sizeFactor");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] SIZEFACTOR = [
      0,
      1
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, SIZEFACTOR.length * float.sizeof, SIZEFACTOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(sizeFactorLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(sizeFactorLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
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

  public static void setColor(vec4 color) {
    program.use();

    program.setUniform("color", color);
  }

  public override void draw(mat4 view) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("pos", pos);
    program.setUniform("size", size);
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao);
    glDrawArrays(GL_LINES, 0, 2);

    glBindVertexArray(0);
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
  vec2 pos;
  vec2 vel;
  float size, trgSize;
  int cnt;
  int num1, num2;

  invariant() {
    if (pos) {
      assert(!pos.x.isNaN);
      assert(!pos.y.isNaN);
      assert(!vel.x.isNaN);
      assert(!vel.y.isNaN);
      assert(size > 0 && size < 10);
    }
  }

  public override void init(Object[] args) {
    pos = vec2(0);
    vel = vec2(0);
    size = 1;
    num1 = 0;
    num2 = -1;
  }

  public override void close() {
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

  public override void draw(mat4 view) {
    if (num2 <= 1) {
      Letter.drawNumSign(view, num1, pos.x + Letter.getWidthNum(num1, size) / 2, pos.y, size);
    } else {
      float wd = Letter.getWidthNum(num1, size) + Letter.getWidth(1, size) + Letter.getWidthNum(num2, size);
      float x;
      x = pos.x - wd / 2 + Letter.getWidthNum(num1, size);
      Letter.drawNumSign(view, num1, x, pos.y, size);
      x = pos.x + wd / 2;
      Letter.drawNumSign(view, num2, x, pos.y, size, 33);
    }
  }
}

public class NumIndicatorPool: ActorPool!(NumIndicator) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
