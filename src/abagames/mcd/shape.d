/*
 * $Id: shape.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.shape;

private import std.typecons;
private import derelict.opengl3.gl;
private import derelict.ode.ode;
private import gl3n.linalg;
private import abagames.util.math;
private import abagames.util.sdl.displaylist;
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
  public void drawShadow(LinePoint lp);
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

  public void drawShadow(LinePoint lp) {
    foreach (Shape s; shapes)
      s.drawShadow(lp);
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
    if (pos.x == 0 && pos.y == 0 && pos.z == 0) {
      dGeomID bg;
      if (!sizeScale.isNull) {
        bg = dCreateBox(sid,
                        size.x * sizeScale.x * shapeBoxScale,
                        size.y * sizeScale.y * shapeBoxScale,
                        size.z * sizeScale.z * shapeBoxScale);
      } else {
        bg = dCreateBox(sid,
                        size.x * shapeBoxScale,
                        size.y * shapeBoxScale,
                        size.z * shapeBoxScale);
      }
      oa.addGeom(bg);
    } else {
      dGeomID tg = dCreateGeomTransform(sid);
      dGeomID bg;
      if (!sizeScale.isNull) {
        bg = dCreateBox(cast(dSpaceID) 0,
                        size.x * sizeScale.x * shapeBoxScale,
                        size.y * sizeScale.y * shapeBoxScale,
                        size.z * sizeScale.z * shapeBoxScale);
        dGeomSetPosition(bg, pos.x * sizeScale.x, pos.y * sizeScale.y, pos.z * sizeScale.z);
      } else {
        bg = dCreateBox(cast(dSpaceID) 0,
                        size.x * shapeBoxScale,
                        size.y * shapeBoxScale,
                        size.z * shapeBoxScale);
        dGeomSetPosition(bg, pos.x, pos.y, pos.z);
      }
      dGeomTransformSetGeom(tg, bg);
      oa.addGeom(tg);
      oa.addTransformedGeom(bg);
    }
  }

  public abstract void recordLinePoints(LinePoint lp);
  public abstract void drawShadow(LinePoint lp);
}

public class Square: ShapeBase {
 private:

  public this(World world, float mass, float px, float py, float sx, float sy) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, 0);
    size = vec3(sx, sy, 1);
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

  public override void drawShadow(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    if (!lp.setShadowColor())
      return;
    glBegin(GL_TRIANGLE_FAN);
    lp.vertex(-1, -1, 0);
    lp.vertex( 1, -1, 0);
    lp.vertex( 1,  1, 0);
    lp.vertex(-1,  1, 0);
    glEnd();
  }
}

public class Sphere: ShapeBase {
 private:

  public this(World world, float mass, float px, float py, float rad) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, 0);
    size = vec3(rad, rad, rad);
  }

  public override void addGeom(OdeActor oa, dSpaceID sid, Nullable!vec3 sizeScale = Nullable!vec3()) {
    if (pos.x == 0 && pos.y == 0 && pos.z == 0) {
      dGeomID bg;
      if (!sizeScale.isNull) {
        bg = dCreateSphere(sid,
                           size.x * sizeScale.x * shapeBoxScale);
      } else {
        bg = dCreateSphere(sid,
                           size.x * shapeBoxScale);
      }
      oa.addGeom(bg);
    } else {
      dGeomID tg = dCreateGeomTransform(sid);
      dGeomID bg;
      if (!sizeScale.isNull) {
        bg = dCreateSphere(cast(dSpaceID) 0,
                           size.x * sizeScale.x * shapeBoxScale);
        dGeomSetPosition(bg, pos.x * sizeScale.x, pos.y * sizeScale.y, pos.z * sizeScale.z);
      } else {
        bg = dCreateSphere(cast(dSpaceID) 0,
                           size.x * shapeBoxScale);
        dGeomSetPosition(bg, pos.x, pos.y, pos.z);
      }
      dGeomTransformSetGeom(tg, bg);
      oa.addGeom(tg);
      oa.addTransformedGeom(bg);
    }
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

  public override void drawShadow(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    if (!lp.setShadowColor())
      return;
    glBegin(GL_TRIANGLE_FAN);
    lp.vertex(-1, -1, 0);
    lp.vertex( 1, -1, 0);
    lp.vertex( 1,  1, 0);
    lp.vertex(-1,  1, 0);
    glEnd();
  }
}

public class Triangle: ShapeBase {
 private:

  public this(World world, float mass, float px, float py, float sx, float sy) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, 0);
    size = vec3(sx, sy, 1);
    shapeBoxScale = 1;
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

  public override void drawShadow(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    if (!lp.setShadowColor())
      return;
    glBegin(GL_TRIANGLE_FAN);
    lp.vertex( 0,  1, 0);
    lp.vertex( 1, -1, 0);
    lp.vertex(-0, -1, 0);
    glEnd();
  }
}

public class Box: ShapeBase {
 private:

  public this(World world, float mass, float px, float py, float pz, float sx, float sy, float sz) {
    this.world = world;
    this.mass = mass;
    pos = vec3(px, py, pz);
    size = vec3(sx, sy, sz);
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

  public override void drawShadow(LinePoint lp) {
    lp.setPos(pos);
    lp.setSize(size);
    if (!lp.setShadowColor())
      return;
    glBegin(GL_QUADS);
    lp.vertex(-1, -1, -1);
    lp.vertex( 1, -1, -1);
    lp.vertex( 1,  1, -1);
    lp.vertex(-1,  1, -1);

    lp.vertex(-1, -1,  1);
    lp.vertex( 1, -1,  1);
    lp.vertex( 1,  1,  1);
    lp.vertex(-1,  1,  1);

    lp.vertex(-1, -1, -1);
    lp.vertex( 1, -1, -1);
    lp.vertex( 1, -1,  1);
    lp.vertex(-1, -1,  1);

    lp.vertex(-1,  1, -1);
    lp.vertex( 1,  1, -1);
    lp.vertex( 1,  1,  1);
    lp.vertex(-1,  1,  1);

    lp.vertex(-1, -1, -1);
    lp.vertex(-1,  1, -1);
    lp.vertex(-1,  1,  1);
    lp.vertex(-1, -1,  1);

    lp.vertex( 1, -1, -1);
    lp.vertex( 1,  1, -1);
    lp.vertex( 1,  1,  1);
    lp.vertex( 1, -1,  1);
    glEnd();
  }
}

public class LinePoint {
 private:
  static const int HISTORY_MAX = 40;
  Field field;
  vec3[] pos;
  vec3[][] posHist;
  int posIdx, histIdx;
  vec3 basePos, baseSize;
  GLfloat[16] m;
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
    posHist = new vec3[][HISTORY_MAX];
    this.field = field;
    foreach (ref vec3 p; pos)
        p = vec3(0);
    foreach (ref vec3[] pp; posHist) {
      pp = new vec3[pointMax];
      foreach (ref vec3 p; pp)
        p = vec3(0);
    }
    spectrumColorRTrg = spectrumColorGTrg = spectrumColorBTrg = 0;
    spectrumLength = 0;
    _alpha = _alphaTrg = 1;
  }

  public void init() nothrow {
    posIdx = 0;
    histIdx = 0;
    isFirstRecord = true;
    spectrumColorR = spectrumColorG = spectrumColorB = 0;
    _enableSpectrumColor = true;
  }

  public void setSpectrumParams(float r, float g, float b, float length) nothrow {
    spectrumColorRTrg = r;
    spectrumColorGTrg = g;
    spectrumColorBTrg = b;
    spectrumLength = length;
  }

  public void beginRecord() {
    posIdx = 0;
    glGetFloatv(GL_MODELVIEW_MATRIX, m.ptr);
  }

  public void setPos(vec3 p) {
    basePos = p;
  }

  public void setSize(vec3 s) nothrow {
    baseSize = s;
  }

  public void record(float ox, float oy, float oz) {
    float tx, ty, tz;
    calcTranslatedPos(tx, ty, tz, ox, oy, oz);
    pos[posIdx].x = tx;
    pos[posIdx].y = ty;
    pos[posIdx].z = tz;
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
          posHist[j][i].x = pos[i].x;
          posHist[j][i].y = pos[i].y;
          posHist[j][i].z = pos[i].z;
        }
      }
    } else {
      for (int i = 0; i < posIdx; i++) {
        posHist[histIdx][i].x = pos[i].x;
        posHist[histIdx][i].y = pos[i].y;
        posHist[histIdx][i].z = pos[i].z;
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
  }

  private void diffuseSpectrum() {
    const float dfr = 0.01f;
    for (int j = 0; j < HISTORY_MAX; j++) {
      for (int i = 0; i < posIdx; i += 2) {
        float ox = posHist[j][i].x - posHist[j][i+1].x;
        float oy = posHist[j][i].y - posHist[j][i+1].y;
        float oz = posHist[j][i].z - posHist[j][i+1].z;
        posHist[j][i].x += ox * dfr;
        posHist[j][i].y += oy * dfr;
        posHist[j][i].z += oz * dfr;
        posHist[j][i+1].x -= ox * dfr;
        posHist[j][i+1].y -= oy * dfr;
        posHist[j][i+1].z -= oz * dfr;
      }
    }
  }

  public void vertex(float ox, float oy, float oz) {
    float tx, ty, tz;
    calcTranslatedPos(tx, ty, tz, ox, oy, oz);
    glVertex3f(tx, ty, tz);
  }

  private void calcTranslatedPos(ref float tx, ref float ty, ref float tz,
                                 float ox, float oy, float oz) {
    float x = basePos.x + baseSize.x / 2 * ox;
    float y = basePos.y + baseSize.y / 2 * oy;
    float z = basePos.z + baseSize.z / 2 * oz;
    tx = m[0] * x + m[4] * y + m[8] * z + m[12];
    ty = m[1] * x + m[5] * y + m[9] * z + m[13];
    tz = m[2] * x + m[6] * y + m[10] * z + m[14];
  }

  public bool setShadowColor() {
    if (spectrumColorR + spectrumColorG + spectrumColorB < 0.1f)
      return false;
    Screen.setColor(spectrumColorR * 0.3f, spectrumColorG * 0.3f, spectrumColorB * 0.3f);
    return true;
  }

  public void draw() {
    if (isFirstRecord)
      return;
    glBegin(GL_LINES);
    for (int i = 0; i < posIdx; i += 2)
      Screen.drawLine(pos[i].x, pos[i].y, pos[i].z,
                      pos[i + 1].x, pos[i + 1].y, pos[i + 1].z, _alpha);
    glEnd();
  }

  public void drawWithSpectrumColor() {
    if (isFirstRecord)
      return;
    if (spectrumColorR + spectrumColorG + spectrumColorB < 0.1f)
      return;
    Screen.setColor(spectrumColorR, spectrumColorG, spectrumColorB);
    glBegin(GL_LINE_STRIP);
    for (int i = 0; i < posIdx; i++)
      glVertex3f(pos[i].x, pos[i].y, pos[i].z);
    glEnd();
  }

  public void drawSpectrum() {
    if (spectrumLength <= 0 || isFirstRecord)
      return;
    if (spectrumColorR + spectrumColorG + spectrumColorB < 0.1f)
      return;
    glBegin(GL_QUADS);
    float al = 0.5f, bl = 0.5f;
    float hif, nhif;
    float hio = 5.5f;
    nhif = histIdx;
    for (int j = 0; j < 10 * spectrumLength; j++) {
      Screen.setColor((spectrumColorR + (1.0f - spectrumColorR) * bl) * al,
                      (spectrumColorG + (1.0f - spectrumColorG) * bl) * al,
                      (spectrumColorB + (1.0f - spectrumColorB) * bl) * al,
                      al);
      hif = nhif;
      nhif = hif - hio;
      if (nhif < 0)
        nhif += HISTORY_MAX;
      int hi = cast(int) hif;
      int nhi = cast(int) nhif;
      if (posHist[hi][0].fastdist(posHist[nhi][0]) < 8) {
        for (int i = 0; i < posIdx; i += 2) {
          glVertex3f(posHist[hi][i].x, posHist[hi][i].y, posHist[hi][i].z);
          glVertex3f(posHist[hi][i+1].x, posHist[hi][i+1].y, posHist[hi][i+1].z);
          glVertex3f(posHist[nhi][i+1].x, posHist[nhi][i+1].y, posHist[nhi][i+1].z);
          glVertex3f(posHist[nhi][i].x, posHist[nhi][i].y, posHist[nhi][i].z);
        }
      }
      al *= 0.88f * spectrumLength;
      bl *= 0.88f * spectrumLength;
    }
    glEnd();
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
  public void draw();
}

public class EyeShape: Drawable {
  public void draw() {
    Screen.setColor(1.0f, 0, 0);
    glBegin(GL_LINE_LOOP);
    glVertex3f(-0.5, 0.5, 0);
    glVertex3f(-0.3, 0.5, 0);
    glVertex3f(-0.3, 0.3, 0);
    glVertex3f(-0.5, 0.3, 0);
    glEnd();
    glBegin(GL_LINE_LOOP);
    glVertex3f(0.5, 0.5, 0);
    glVertex3f(0.3, 0.5, 0);
    glVertex3f(0.3, 0.3, 0);
    glVertex3f(0.5, 0.3, 0);
    glEnd();
    Screen.setColor(0.8f, 0.4f, 0.4f);
    glBegin(GL_TRIANGLE_FAN);
    glVertex3f(-0.5, 0.5, 0);
    glVertex3f(-0.3, 0.5, 0);
    glVertex3f(-0.3, 0.3, 0);
    glVertex3f(-0.5, 0.3, 0);
    glEnd();
    glBegin(GL_TRIANGLE_FAN);
    glVertex3f(0.5, 0.5, 0);
    glVertex3f(0.3, 0.5, 0);
    glVertex3f(0.3, 0.3, 0);
    glVertex3f(0.5, 0.3, 0);
    glEnd();
  }
}

public class CenterShape: Drawable {
  public void draw() {
    Screen.setColor(0.6f, 1.0f, 0.5f);
    glBegin(GL_TRIANGLE_FAN);
    glVertex3f(-0.2, -0.2, 0);
    glVertex3f( 0.2, -0.2, 0);
    glVertex3f( 0.2,  0.2, 0);
    glVertex3f(-0.2,  0.2, 0);
    glEnd();
    Screen.setColor(0.4f, 0.8f, 0.2f);
    glBegin(GL_TRIANGLE_FAN);
    glVertex3f(-0.6, 0.6, 0);
    glVertex3f(-0.3, 0.6, 0);
    glVertex3f(-0.3, 0.3, 0);
    glVertex3f(-0.6, 0.3, 0);
    glEnd();
    glBegin(GL_TRIANGLE_FAN);
    glVertex3f(0.6, 0.6, 0);
    glVertex3f(0.3, 0.6, 0);
    glVertex3f(0.3, 0.3, 0);
    glVertex3f(0.6, 0.3, 0);
    glEnd();
  }
}
