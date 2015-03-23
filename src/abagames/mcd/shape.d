/*
 * $Id: shape.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.shape;

private import std.typecons;
private import derelict.ode.ode;
private import gl3n.linalg;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
private import abagames.util.ode.odeactor;
private import abagames.util.ode.world;
private import abagames.mcd.screen;
private import abagames.mcd.field;

/**
 * Vector style shape.
 * Handling mass and geom of a object.
 */
public interface Shape {
  public void addMass(dMass* m, Nullable!vec3 sizeScale = Nullable!vec3(), float massScale = 1);
  public void addGeom(OdeActor oa, dSpaceID sid, Nullable!vec3 sizeScale = Nullable!vec3());
  public void recordLinePoints(LinePoint lp);
  public void drawShadow(mat4 view, LinePoint lp);
}

public class ShapeGroup: Shape {
 private:
  Shape[] shapes;

  public void addShape(Shape s) {
    shapes ~= s;
  }

  public void setMass(OdeActor oa, Nullable!vec3 sizeScale = Nullable!vec3(), float massScale = 1) {
    dMass m;
    dMassSetZero(&m);
    addMass(&m, sizeScale, massScale);
    oa.setMass(m);
  }

  public void setGeom(OdeActor oa, dSpaceID sid, Nullable!vec3 sizeScale = Nullable!vec3()) {
    addGeom(oa, sid, sizeScale);
  }

  public void addMass(dMass *m, Nullable!vec3 sizeScale = Nullable!vec3(), float massScale = 1) {
    foreach (Shape s; shapes)
      s.addMass(m, sizeScale, massScale);
  }

  public void addGeom(OdeActor oa, dSpaceID sid, Nullable!vec3 sizeScale = Nullable!vec3()) {
    foreach (Shape s; shapes)
      s.addGeom(oa, sid, sizeScale);
  }

  public void recordLinePoints(LinePoint lp) {
    foreach (Shape s; shapes)
      s.recordLinePoints(lp);
  }

  public void drawShadow(mat4 view, LinePoint lp) {
    foreach (Shape s; shapes)
      s.drawShadow(view, lp);
  }
}


public abstract class ShapeBase: Shape {
 protected:
  World world;
  vec3 pos;
  vec3 size;
  float mass = 1;
  float shapeBoxScale = 1;

  invariant() {
    if (pos) {
      assert(!pos.x.isNaN);
      assert(!pos.y.isNaN);
      assert(!pos.z.isNaN);
      assert(size.x >= 0);
      assert(size.y >= 0);
      assert(size.z >= 0);
      assert(mass >= 0);
    }
  }

  public void addMass(dMass* m, Nullable!vec3 sizeScale = Nullable!vec3(), float massScale = 1) {
    dMass sm;
    if (!sizeScale.isNull) {
      dMassSetBox(&sm, 1, size.x * sizeScale.x, size.y * sizeScale.y, size.z * sizeScale.z);
      dMassTranslate(&sm, pos.x * sizeScale.x, pos.y * sizeScale.y, pos.z * sizeScale.z);
    } else {
      dMassSetBox(&sm, 1, size.x, size.y, size.z);
      dMassTranslate(&sm, pos.x, pos.y, pos.z);
    }
    dMassAdjust(&sm, mass * massScale);
    dMassAdd(m, &sm);
  }

  public void addGeom(OdeActor oa, dSpaceID sid, Nullable!vec3 sizeScale = Nullable!vec3()) {
    dGeomID bg;
    if (!sizeScale.isNull) {
      bg = dCreateBox(sid,
                      size.x * sizeScale.x * shapeBoxScale,
                      size.y * sizeScale.y * shapeBoxScale,
                      size.z * sizeScale.z * shapeBoxScale);
      vec3 offset = vec3(pos.x * sizeScale.x,
                         pos.y * sizeScale.y,
                         pos.z * sizeScale.z);
      dGeomSetPosition(bg, offset.x, offset.y, offset.z);
    } else {
      bg = dCreateBox(sid,
                      size.x * shapeBoxScale,
                      size.y * shapeBoxScale,
                      size.z * shapeBoxScale);
      dGeomSetPosition(bg, pos.x, pos.y, pos.z);
    }
    oa.addGeom(bg);
  }

  public abstract void recordLinePoints(LinePoint lp);
  public abstract void drawShadow(mat4 view, LinePoint lp);
}

public class Square: ShapeBase {
 private:
  static GLuint vao = 0;
  static GLuint vbo = 0;

  public this(World world, float mass, float px, float py, float sx, float sy) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, 0);
    size = vec3(sx, sy, 1);

    if (vao) {
      return;
    }

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    static const float[] BUF = [
      /*
      pos,       padding */
      -1, -1, 0, 0,
       1, -1, 0, 0,
       1,  1, 0, 0,
      -1,  1, 0, 0
    ];
    enum POS = 0;
    enum BUFSZ = 4;

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(LinePoint.posLoc, 3, BUFSZ, POS);
    glEnableVertexAttribArray(LinePoint.posLoc);
  }

  public static void close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
  }

  public this(World world, float mass, float px, float py, float pz,
              float sx, float sy, float sz) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, pz);
    size = vec3(sx, sy, sz);
  }

  public override void recordLinePoints(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    lp.record(-1, -1, 0);
    lp.record( 1, -1, 0);
    lp.record( 1, -1, 0);
    lp.record( 1,  1, 0);
    lp.record( 1,  1, 0);
    lp.record(-1,  1, 0);
    lp.record(-1,  1, 0);
    lp.record(-1, -1, 0);
  }

  public override void drawShadow(mat4 view, LinePoint lp) {
    if (!lp.prepareDraw(view, pos, size)) {
      return;
    }

    LinePoint.useVao(vao);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
  }
}

public class Sphere: ShapeBase {
 private:
  static GLuint vao = 0;
  static GLuint vbo = 0;

  public this(World world, float mass, float px, float py, float rad) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, 0);
    size = vec3(rad, rad, rad);

    if (vao) {
      return;
    }

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    static const float[] BUF = [
      /*
      pos,       padding */
      -1, -1, 0, 0,
       1, -1, 0, 0,
       1,  1, 0, 0,
      -1,  1, 0, 0
    ];
    enum POS = 0;
    enum BUFSZ = 4;

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(LinePoint.posLoc, 3, BUFSZ, POS);
    glEnableVertexAttribArray(LinePoint.posLoc);
  }

  public static void close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
  }

  public override void addGeom(OdeActor oa, dSpaceID sid, Nullable!vec3 sizeScale = Nullable!vec3()) {
    dGeomID bg;
    if (!sizeScale.isNull) {
      bg = dCreateSphere(cast(dSpaceID) 0,
                         size.x * sizeScale.x * shapeBoxScale);
      vec3 offset = vec3(pos.x * sizeScale.x,
                         pos.y * sizeScale.y,
                         pos.z * sizeScale.z);
      dGeomSetPosition(bg, offset.x, offset.y, offset.z);
    } else {
      bg = dCreateSphere(cast(dSpaceID) 0,
                         size.x * shapeBoxScale);
      dGeomSetPosition(bg, pos.x, pos.y, pos.z);
    }
    oa.addGeom(bg);
  }

  public override void recordLinePoints(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    lp.record(-1, -1, 0);
    lp.record( 1, -1, 0);
    lp.record( 1, -1, 0);
    lp.record( 1,  1, 0);
    lp.record( 1,  1, 0);
    lp.record(-1,  1, 0);
    lp.record(-1,  1, 0);
    lp.record(-1, -1, 0);
  }

  public override void drawShadow(mat4 view, LinePoint lp) {
    if (!lp.prepareDraw(view, pos, size)) {
      return;
    }

    LinePoint.useVao(vao);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
  }
}

public class Triangle: ShapeBase {
 private:
  static GLuint vao = 0;
  static GLuint vbo = 0;

  public this(World world, float mass, float px, float py, float sx, float sy) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, 0);
    size = vec3(sx, sy, 1);
    shapeBoxScale = 1;

    if (vao) {
      return;
    }

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    static const float[] BUF = [
      /*
      pos,       padding */
       0,  1, 0, 0,
       1, -1, 0, 0,
      -0, -1, 0, 0
    ];
    enum POS = 0;
    enum BUFSZ = 4;

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(LinePoint.posLoc, 3, BUFSZ, POS);
    glEnableVertexAttribArray(LinePoint.posLoc);
  }

  public static void close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
  }

  public override void recordLinePoints(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    lp.record( 0,  1, 0);
    lp.record( 1, -1, 0);
    lp.record( 1, -1, 0);
    lp.record(-1, -1, 0);
    lp.record(-1, -1, 0);
    lp.record( 0,  1, 0);
  }

  public override void drawShadow(mat4 view, LinePoint lp) {
    if (!lp.prepareDraw(view, pos, size)) {
      return;
    }

    LinePoint.useVao(vao);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 3);
  }
}

public class Box: ShapeBase {
 private:
  static GLuint vao = 0;
  static GLuint vbo = 0;

  public this(World world, float mass, float px, float py, float pz, float sx, float sy, float sz) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, pz);
    size = vec3(sx, sy, sz);

    if (vao) {
      return;
    }

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    static const float[] BUF = [
      /*
      pos,        padding */
      -1, -1, -1, 0,
       1, -1, -1, 0,
       1,  1, -1, 0,
      -1,  1, -1, 0,

      -1, -1,  1, 0,
       1, -1,  1, 0,
       1,  1,  1, 0,
      -1,  1,  1, 0
    ];
    enum POS = 0;
    enum BUFSZ = 4;

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(LinePoint.posLoc, 3, BUFSZ, POS);
    glEnableVertexAttribArray(LinePoint.posLoc);
  }

  public static void close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
  }

  public override void recordLinePoints(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    lp.record(-1, -1, -1);
    lp.record( 1, -1, -1);
    lp.record( 1, -1, -1);
    lp.record( 1,  1, -1);
    lp.record( 1,  1, -1);
    lp.record(-1,  1, -1);
    lp.record(-1,  1, -1);
    lp.record(-1, -1, -1);

    lp.record(-1, -1,  1);
    lp.record( 1, -1,  1);
    lp.record( 1, -1,  1);
    lp.record( 1,  1,  1);
    lp.record( 1,  1,  1);
    lp.record(-1,  1,  1);
    lp.record(-1,  1,  1);
    lp.record(-1, -1,  1);

    lp.record(-1, -1,  1);
    lp.record(-1, -1, -1);
    lp.record( 1, -1,  1);
    lp.record( 1, -1, -1);
    lp.record( 1,  1,  1);
    lp.record( 1,  1, -1);
    lp.record(-1,  1,  1);
    lp.record(-1,  1, -1);
  }

  public override void drawShadow(mat4 view, LinePoint lp) {
    if (!lp.prepareDraw(view, pos, size)) {
      return;
    }

    static const GLubyte[] IDX = [
      0, 1, 2, 3,
      4, 5, 6, 7,
      0, 1, 5, 4,
      3, 2, 6, 7,
      0, 3, 7, 4,
      1, 2, 6, 5
    ];

    LinePoint.useVao(vao);
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, IDX.ptr +  0);
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, IDX.ptr +  4);
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, IDX.ptr +  8);
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, IDX.ptr + 12);
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, IDX.ptr + 16);
    glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, IDX.ptr + 20);
  }
}

public class LinePoint {
 public:
  static const GLuint posLoc = 0;
 private:
  static const int HISTORY_MAX = 40;
  static ShaderProgram program;
  static ShaderProgram spectrumBorderProgram;
  static ShaderProgram spectrumProgram;
  static GLuint[2] vao;
  Field field;
  vec3[] pos;
  vec3[] posHist;
  int posIdx, histIdx;
  vec3 basePos, baseSize;
  mat4 m;
  GLuint[2] vbo;
  bool isFirstRecord;
  float spectrumColorR, spectrumColorG, spectrumColorB;
  float spectrumColorRTrg, spectrumColorGTrg, spectrumColorBTrg;
  float spectrumLength;
  float _alpha, _alphaTrg;
  bool _enableSpectrumColor;

  invariant() {
    if (pos) {
      assert(posIdx >= 0);
      assert(histIdx >= 0 && histIdx < HISTORY_MAX);
      assert(spectrumLength >= 0 && spectrumLength <= 1);
      assert(_alpha >= 0 && _alpha <= 1);
      assert(spectrumColorRTrg >= 0 && spectrumColorRTrg <= 1);
      assert(spectrumColorGTrg >= 0 && spectrumColorGTrg <= 1);
      assert(spectrumColorBTrg >= 0 && spectrumColorBTrg <= 1);
      assert(spectrumColorR >= 0 && spectrumColorR <= 1);
      assert(spectrumColorG >= 0 && spectrumColorG <= 1);
      assert(spectrumColorB >= 0 && spectrumColorB <= 1);
      for (int i = 0; i < posIdx; i++) {
        assert(!pos[i].x.isNaN);
        assert(!pos[i].y.isNaN);
        assert(!pos[i].z.isNaN);
      }
    }
  }

  public this(Field field, int pointMax = 8) {
    init();
    pos = new vec3[pointMax];
    posHist = new vec3[HISTORY_MAX * pointMax];
    this.field = field;
    foreach (ref vec3 p; pos)
      p = vec3(0);
    foreach (ref vec3 p; posHist) {
      p = vec3(0);
    }
    spectrumColorRTrg = spectrumColorGTrg = spectrumColorBTrg = 0;
    spectrumLength = 0;
    _alpha = _alphaTrg = 1;

    glGenBuffers(2, vbo.ptr);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, 3 * pointMax * float.sizeof, null, GL_DYNAMIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, 3 * HISTORY_MAX * pointMax * float.sizeof, null, GL_DYNAMIC_DRAW);
  }

  public ~this() {
    glDeleteBuffers(2, vbo.ptr);
  }

  public void init() nothrow {
    posIdx = 0;
    histIdx = 0;
    isFirstRecord = true;
    spectrumColorR = spectrumColorG = spectrumColorB = 0;
    _enableSpectrumColor = true;
  }

  public static void initPrograms() {
    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 transmat;\n"
      "uniform vec3 basePos;\n"
      "uniform vec3 baseSize;\n"
      "\n"
      "attribute vec3 pos;\n"
      "\n"
      "void main() {\n"
      "  vec4 pos4 = transmat * vec4(basePos + 0.5 * baseSize * pos, 1);\n"
      "  gl_Position = projmat * vec4(pos4.xyz, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    program.bindAttribLocation(posLoc, "pos");
    program.link();

    spectrumBorderProgram = new ShaderProgram;
    spectrumBorderProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "\n"
      "attribute vec3 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(pos, 1);\n"
      "}\n"
    );
    spectrumBorderProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    spectrumBorderProgram.bindAttribLocation(posLoc, "pos");
    spectrumBorderProgram.link();
    spectrumBorderProgram.use();

    glGenVertexArrays(2, vao.ptr);

    enum POS = 0;
    enum BUFSZ = 3;

    glBindVertexArray(vao[0]);
    glEnableVertexAttribArray(posLoc);

    spectrumProgram = new ShaderProgram;
    spectrumProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "\n"
      "attribute vec3 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(pos, 1);\n"
      "}\n"
    );
    spectrumProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 base_color;\n"
      "uniform float a;\n"
      "uniform float b;\n"
      "\n"
      "void main() {\n"
      "  vec3 inv_color = vec3(1) - base_color;\n"
      "  vec3 color = base_color + inv_color * b;\n"
      "  gl_FragColor = vec4(a) * vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    spectrumProgram.bindAttribLocation(posLoc, "pos");
    spectrumProgram.link();
    spectrumProgram.use();

    glBindVertexArray(vao[1]);
    glEnableVertexAttribArray(posLoc);
  }

  public static void close() {
    glDeleteVertexArrays(2, vao.ptr);

    program.close();
    spectrumBorderProgram.close();
    spectrumProgram.close();
  }

  public void setSpectrumParams(float r, float g, float b, float length) nothrow {
    spectrumColorRTrg = r;
    spectrumColorGTrg = g;
    spectrumColorBTrg = b;
    spectrumLength = length;
  }

  public void beginRecord(mat4 model) {
    posIdx = 0;
    m = model;
  }

  public void setPos(vec3 p) {
    basePos = p;
  }

  public void setSize(vec3 s) nothrow {
    baseSize = s;
  }

  public void record(float ox, float oy, float oz) {
    pos[posIdx] = calcTranslatedPos(ox, oy, oz);
    posIdx++;
  }

  public void endRecord() {
    histIdx++;
    if (histIdx >= HISTORY_MAX)
      histIdx = 0;
    if (isFirstRecord) {
      isFirstRecord = false;
      for (int j = 0; j < HISTORY_MAX; j++) {
        for (int i = 0; i < posIdx; i++) {
          posHist[j * posIdx + i] = pos[i];
        }
      }
    } else {
      for (int i = 0; i < posIdx; i++) {
        posHist[histIdx * posIdx + i] = pos[i];
      }
    }
    diffuseSpectrum();
    if (_enableSpectrumColor) {
      spectrumColorR += (spectrumColorRTrg - spectrumColorR) * 0.1f;
      spectrumColorG += (spectrumColorGTrg - spectrumColorG) * 0.1f;
      spectrumColorB += (spectrumColorBTrg - spectrumColorB) * 0.1f;
    } else {
      spectrumColorR *= 0.9f;
      spectrumColorG *= 0.9f;
      spectrumColorB *= 0.9f;
    }
    _alpha += (_alphaTrg - _alpha) * 0.05f;

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferSubData(GL_ARRAY_BUFFER, 0, 3 * posIdx * float.sizeof, pos.ptr);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferSubData(GL_ARRAY_BUFFER, 0, 3 * HISTORY_MAX * posIdx * float.sizeof, posHist.ptr);
  }

  private void diffuseSpectrum() {
    const float dfr = 0.01f;
    for (int j = 0; j < HISTORY_MAX; j++) {
      size_t base = j * posIdx;
      for (int i = 0; i < posIdx - 1; i += 2) {
        vec3 o = posHist[base + i] - posHist[base + i + 1];
        posHist[base + i + 0] += o * dfr;
        posHist[base + i + 1] -= o * dfr;
      }
    }
  }

  public bool prepareDraw(mat4 view, vec3 pos, vec3 size) {
    program.use();

    if (!setShadowColor()) {
      return false;
    }

    program.setUniform("projmat", view);
    program.setUniform("transmat", m);
    program.setUniform("basePos", pos);
    program.setUniform("baseSize", size);
    program.setUniform("brightness", Screen.brightness);

    return true;
  }

  public static void useVao(GLuint vao) {
    program.useVao(vao);
  }

  private vec3 calcTranslatedPos(float ox, float oy, float oz) {
    vec3 o = vec3(ox, oy, oz);
    vec3 sz = vec3(baseSize.x * o.x, baseSize.y * o.y, baseSize.z * o.z);
    vec3 tpos = basePos + sz * 0.5f;
    vec4 trans = m * vec4(tpos, 1);
    return trans.xyz;
  }

  private bool setShadowColor() {
    if (spectrumColorR + spectrumColorG + spectrumColorB < 0.1f)
      return false;
    program.setUniform("color", vec3(spectrumColorR, spectrumColorG, spectrumColorB) * 0.3f);
    return true;
  }

  public void draw(mat4 view) {
    if (isFirstRecord)
      return;
    for (int i = 0; i < posIdx - 1; i += 2)
      Screen.drawLine(view, pos[i].x, pos[i].y, pos[i].z,
                            pos[i + 1].x, pos[i + 1].y, pos[i + 1].z, _alpha);
  }

  public void drawWithSpectrumColor(mat4 view) {
    if (isFirstRecord)
      return;
    if (spectrumColorR + spectrumColorG + spectrumColorB < 0.1f)
      return;

    spectrumBorderProgram.use();

    spectrumBorderProgram.setUniform("projmat", view);
    spectrumBorderProgram.setUniform("brightness", Screen.brightness);
    spectrumBorderProgram.setUniform("color", spectrumColorR, spectrumColorG, spectrumColorB);

    spectrumBorderProgram.useVao(vao[0]);
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    vertexAttribPointer(posLoc, 3, 3, 0);

    glDrawArrays(GL_LINE_STRIP, 0, posIdx);
  }

  public void drawSpectrum(mat4 view) {
    if (spectrumLength <= 0 || isFirstRecord)
      return;
    if (spectrumColorR + spectrumColorG + spectrumColorB < 0.1f)
      return;

    spectrumProgram.use();

    spectrumProgram.setUniform("projmat", view);
    spectrumProgram.setUniform("brightness", Screen.brightness);
    spectrumProgram.setUniform("base_color", spectrumColorR, spectrumColorG, spectrumColorB);

    spectrumProgram.useVao(vao[1]);
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    vertexAttribPointer(posLoc, 3, 3, 0);

    float al = 0.5f, bl = 0.5f;
    float hif, nhif;
    float hio = 5.5f;
    nhif = histIdx;
    for (int j = 0; j < 10 * spectrumLength; j++) {
      spectrumProgram.setUniform("a", al);
      spectrumProgram.setUniform("b", bl);

      hif = nhif;
      nhif = hif - hio;
      if (nhif < 0)
        nhif += HISTORY_MAX;
      int hi = cast(int) hif;
      int nhi = cast(int) nhif;
      if (posHist[hi * posIdx].fastdist(posHist[nhi * posIdx]) < 8) {
        for (int i = 0; i < posIdx - 1; i += 2) {
          const GLushort[] idx = [
            cast(GLushort) ( hi * posIdx + i + 0),
            cast(GLushort) ( hi * posIdx + i + 1),
            cast(GLushort) (nhi * posIdx + i + 1),
            cast(GLushort) (nhi * posIdx + i + 0),
          ];

          glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_SHORT, idx.ptr);
        }
      }
      al *= 0.88f * spectrumLength;
      bl *= 0.88f * spectrumLength;
    }
  }

  public float alpha(float v) {
    return _alpha = v;
  }

  public float alphaTrg(float v) {
    return _alphaTrg = v;
  }

  public bool enableSpectrumColor(bool v) {
    return _enableSpectrumColor = v;
  }
}

public interface Drawable {
  public void draw(mat4 view, mat4 model);
}

public class EyeShape: Drawable {
 private:
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;

  public this() {
    if (program !is null) {
      return;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "uniform vec2 factor;\n"
      "\n"
      "attribute vec2 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * modelmat * vec4(pos * factor, 0, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    GLint posLoc = 0;
    program.bindAttribLocation(posLoc, "pos");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] BUF = [
      /*
      pos */
      0.5f, 0.5f,
      0.3f, 0.5f,
      0.3f, 0.3f,
      0.5f, 0.3f
    ];
    enum POS = 0;
    enum BUFSZ = 2;

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(posLoc, 2, BUFSZ, POS);
    glEnableVertexAttribArray(posLoc);
  }

  public static void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
  }

  public void draw(mat4 view, mat4 model) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("modelmat", model);
    program.setUniform("brightness", Screen.brightness);

    program.useVao(vao);

    program.setUniform("color", 1.0f, 0, 0);

    program.setUniform("factor", -1, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 4);

    program.setUniform("factor", 1, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 4);

    program.setUniform("color", 0.8f, 0.4f, 0.4f);

    program.setUniform("factor", -1, 1);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    program.setUniform("factor", 1, 1);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
  }
}

public class CenterShape: Drawable {
  private:
   static ShaderProgram program;
   static GLuint vao;
   static GLuint vbo;

   public this() {
     if (program !is null) {
       return;
     }

     program = new ShaderProgram;
     program.setVertexShader(
       "uniform mat4 projmat;\n"
       "uniform mat4 modelmat;\n"
       "uniform vec2 factor;\n"
       "\n"
       "attribute vec2 pos;\n"
       "\n"
       "void main() {\n"
       "  gl_Position = projmat * modelmat * vec4(pos * factor, 0, 1);\n"
       "}\n"
     );
     program.setFragmentShader(
       "uniform float brightness;\n"
       "uniform vec3 color;\n"
       "\n"
       "void main() {\n"
       "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
       "}\n"
     );
     GLint posLoc = 0;
     program.bindAttribLocation(posLoc, "pos");
     program.link();
     program.use();

     glGenBuffers(1, &vbo);
     glGenVertexArrays(1, &vao);

     static const float[] BUF = [
       /*
       pos */
       -1,   -1,
        1,   -1,
        1,    1,
       -1,    1,

       0.6f,  0.6f,
       0.3f,  0.6f,
       0.3f,  0.3f,
       0.6f,  0.3f
     ];
     enum POS = 0;
     enum BUFSZ = 2;

     glBindVertexArray(vao);

     glBindBuffer(GL_ARRAY_BUFFER, vbo);
     glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

     vertexAttribPointer(posLoc, 2, BUFSZ, POS);
     glEnableVertexAttribArray(posLoc);
   }

  public static void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
  }

  public void draw(mat4 view, mat4 model) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("modelmat", model);
    program.setUniform("brightness", Screen.brightness);

    program.useVao(vao);

    program.setUniform("color", 0.6f, 1.0f, 0.5f);
    program.setUniform("factor", 0.2f, 0.2f);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    program.setUniform("color", 0.4f, 0.8f, 0.2f);

    program.setUniform("factor", -1, 1);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);

    program.setUniform("factor", 1, 1);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
  }
}
