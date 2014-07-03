/*
 * $Id: field.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.field;

private import std.math;
private import derelict.ode.ode;
private import gl3n.linalg;
private import abagames.util.math;
private import abagames.util.rand;
private import abagames.util.support.gl;
private import abagames.util.sdl.texture;
private import abagames.util.ode.world;
private import abagames.util.ode.odeactor;
private import abagames.mcd.screen;
private import abagames.mcd.shape;
private import abagames.mcd.particle;
private import abagames.mcd.ship;
private import abagames.mcd.gamemanager;

/**
 * Game field (floor, stars and overlay).
 */
public class Field {
 public:
  static const float GRAVITY = 4.2f;
 private:
  static const float EYE_POS_Y = -2.5f;
  static const float EYE_POS_Z = 15f;
  static Rand rand;
  Screen screen;
  World world;
  GameManager gameManager;
  Ship ship;
  StarParticlePool starParticles;
  vec2 _size;
  vec2 eyePos, eyePosSize;
  Wall floorWall;
  Texture _titleTexture;
  int cnt;

  invariant() {
    if(eyePos) {
      assert(eyePos.x < 100 && eyePos.x > -100);
      assert(eyePos.y < 100 && eyePos.y > -100);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(Screen screen, World world, GameManager gameManager) {
    this.screen = screen;
    this.world = world;
    this.gameManager = gameManager;
    _size = vec2(20, 15);
    eyePos = vec2(0);
    eyePosSize = vec2(_size.x - 12, size.y - 9);
    _titleTexture = new Texture("title.bmp", 0, 0, 5, 1, 64, 64, 4278190080u);
    floorWall = new FloorWall;
    floorWall.setWorld(world);
    floorWall.init(null);
  }

  public void start() {
    floorWall.set(false);
    ShapeGroup s = new ShapeGroup;
    s.addShape(new Square(world, 9999999, 0, 0, -6, _size.x * 2, _size.y * 2, 10));
    s.addGeom(floorWall, world.space);
    cnt = 0;
    eyePos.x = eyePos.y = 0;
  }

  public void clear() {
    floorWall.remove();
  }

  public void setShip(Ship ship) {
    this.ship = ship;
  }

  public void setStarParticles(StarParticlePool starParticles) {
    this.starParticles = starParticles;
  }

  public void move() {
    cnt--;
    if (cnt < 0) {
      StarParticle sp = starParticles.getInstance();
      if (sp) {
        float sz = 0.25f + rand.nextFloat(0.5f);
        float x, y;
        if (rand.nextInt(2) == 0) {
          x = rand.nextSignedFloat(_size.x * 2.0f);
          y = _size.y + rand.nextFloat(_size.y) * 1.5f;
          if (rand.nextInt(2) == 0)
            y *= -1;
        } else {
          x = _size.x + rand.nextFloat(_size.x) * 1.5f;
          if (rand.nextInt(2) == 0)
            x *= -1;
          y = rand.nextSignedFloat(_size.y * 2.0f);
        }
        sp.set(x, y, 16,
               (0.05f + rand.nextFloat(0.05f)) / sz, sz);
      }
      cnt = 3;
    }
    setEyePos();
  }

  private void setEyePos() {
    float tx = ship.pos.x, ty = ship.pos.y;
    if (checkInField(ship.pos)) {
      if (tx < -eyePosSize.x)
        tx = -eyePosSize.x;
      else if (tx > eyePosSize.x)
        tx = eyePosSize.x;
      if (ty < -eyePosSize.y)
        ty = -eyePosSize.y;
      else if (ty > eyePosSize.y)
        ty = eyePosSize.y;
    }
    eyePos.x += (tx - eyePos.x) * 0.05f;
    eyePos.y += (ty - eyePos.y) * 0.05f;
  }

  private mat4 lookAt(float ex, float ey, float ez,
                      float lx, float ly, float lz,
                      float ux, float uy, float uz) {
    mat4 mat = mat4.look_at(vec3(ex, ey, ez),
                            vec3(lx, ly, lz),
                            vec3(ux, uy, uz));
    mat.transpose();

    glMultMatrixf(mat.value_ptr);

    mat.transpose();
    return mat;
  }

  public mat4 setLookAt() {
    glMatrixMode(GL_PROJECTION);
    mat4 view = screen.setPerspective();
    view = view * lookAt(eyePos.x, eyePos.y + EYE_POS_Y, EYE_POS_Z, eyePos.x, eyePos.y, 0, 0, 1, 0);
    glMatrixMode(GL_MODELVIEW);
    return view;
  }

  public mat4 setLookAtTitle() {
    glMatrixMode(GL_PROJECTION);
    mat4 view = screen.setPerspective();
    view = view * lookAt(0, EYE_POS_Y, EYE_POS_Z, 0, 0, 0, 0, 1, 0);
    glMatrixMode(GL_MODELVIEW);
    return view;
  }

  public void draw(mat4 view) {
    glBegin(GL_LINES);
    for (int z = 0; z > -8; z--) {
      float a = 1;
      if (z < 0)
        a = 0.8f + z * 0.05f;
      drawSquare(view, -_size.x, -_size.y, _size.x * 2, _size.y * 2, z, a);
    }
    for (float w = 0.98f; w < 1.0f; w += 0.0033f)
      drawSquare(view, -_size.x * w, -_size.y * w, _size.x * w * 2, _size.y * w * 2, 0, 0.9f);
    for (float x = -0.9f; x < 1.0f; x += 0.1f) {
      Screen.setColor(1, 1, 1);
      glVertex3f(_size.x * x, -_size.y, 0);
      Screen.setColor(0.4f, 0.4f, 0.4f);
      glVertex3f(_size.x * x, -_size.y, -8);
      Screen.setColor(1, 1, 1);
      glVertex3f(_size.x * x, _size.y, 0);
      Screen.setColor(0.4f, 0.4f, 0.4f);
      glVertex3f(_size.x * x, _size.y, -8);
    }
    for (float y = -1; y < 1.1f; y += 0.1f) {
      Screen.setColor(1, 1, 1);
      glVertex3f(-_size.x, _size.y * y, 0);
      Screen.setColor(0.4f, 0.4f, 0.4f);
      glVertex3f(-_size.x, _size.y * y, -8);
      Screen.setColor(1, 1, 1);
      glVertex3f(_size.x, _size.y * y, 0);
      Screen.setColor(0.4f, 0.4f, 0.4f);
      glVertex3f(_size.x, _size.y * y, -8);
    }
    glEnd();
  }

  private void drawSquare(mat4 view, float x, float y, float w, float h, float z, float a) {
    Screen.drawLine(view, x, y, z, x + w, y, z, a);
    Screen.drawLine(view, x + w, y, z, x + w, y + h, z, a);
    Screen.drawLine(view, x + w, y + h, z, x, y + h, z, a);
    Screen.drawLine(view, x, y + h, z, x, y, z, a);
  }

  static const float[][] OVERLAY_BAR_POS = [
    [370, 466, 0, 7], [615, 466, 0, 7],
    [631, 450, 7, 0], [631, 30, 7, 0],
    [615, 14, 0, -7], [25, 14, 0, -7],
    [9, 30, -7, 0], [9, 450, -7, 0],
    [25, 466, 0, 7], [270, 466, 0, 7],
  ];

  public void drawOverlay(mat4 view) {
    viewOrthoFixed();
    gameManager.drawState(view);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBegin(GL_QUADS);
    for (int i = 1; i < OVERLAY_BAR_POS.length; i++) {
      float x1 = OVERLAY_BAR_POS[i - 1][0];
      float y1 = OVERLAY_BAR_POS[i - 1][1];
      float ox1 = OVERLAY_BAR_POS[i - 1][2];
      float oy1 = OVERLAY_BAR_POS[i - 1][3];
      float x2 = OVERLAY_BAR_POS[i][0];
      float y2 = OVERLAY_BAR_POS[i][1];
      float ox2 = OVERLAY_BAR_POS[i][2];
      float oy2 = OVERLAY_BAR_POS[i][3];
      Screen.setColor(1, 0, 0);
      glVertex3f(x1 - ox1, y1 - oy1, 0);
      glVertex3f(x2 - ox2, y2 - oy2, 0);
      glVertex3f(x2 + ox2, y2 + oy2, 0);
      glVertex3f(x1 + ox1, y1 + oy1, 0);
      ox1 *= 0.5f;
      oy1 *= 0.5f;
      ox2 *= 0.5f;
      oy2 *= 0.5f;
      Screen.setColor(1, 1, 1);
      glVertex3f(x1 - ox1, y1 - oy1, 0);
      glVertex3f(x2 - ox2, y2 - oy2, 0);
      glVertex3f(x2 + ox2, y2 + oy2, 0);
      glVertex3f(x1 + ox1, y1 + oy1, 0);
    }
    glEnd();
    glEnable(GL_TEXTURE_2D);
    float x = 285, y = 465;
    float lsz = 26, lof = 20;
    for (int i = 0; i < 5; i++) {
      glBlendFunc(GL_DST_COLOR,GL_ZERO);
      Screen.setColorForced(1, 1, 1);
      _titleTexture.bindMask(i);
      drawLetter(view, i, x, y, lsz);
      glBlendFunc(GL_ONE, GL_ONE);
      Screen.setColor(1, 0, 0);
      _titleTexture.bind(i);
      drawLetter(view, i, x, y, lsz);
      glBlendFunc(GL_DST_COLOR,GL_ZERO);
      glBlendFunc(GL_ONE, GL_ONE);
      Screen.setColor(1, 1, 1);
      _titleTexture.bind(i);
      drawLetter(view, i, x, y, lsz);
      if (i == 0)
        x += lof * 1.0f;
      else
        x += lof * 0.9f;
    }
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glDisable(GL_TEXTURE_2D);
    viewPerspective();
  }

  public void drawLetter(mat4 view, int i, float cx, float cy, float width) {
    glBegin(GL_TRIANGLE_FAN);
    glTexCoord2f(0, 0);
    glVertex3f(cx - width / 2, cy - width / 2, 0);
    glTexCoord2f(1, 0);
    glVertex3f(cx + width / 2, cy - width / 2, 0);
    glTexCoord2f(1, 1);
    glVertex3f(cx + width / 2, cy + width / 2, 0);
    glTexCoord2f(0, 1);
    glVertex3f(cx - width / 2, cy + width / 2, 0);
    glEnd();
  }

  public mat4 fixedOrthoView() {
    // TODO: Remove the 640x480 assumption.
    return mat4.orthographic(0, 640, 480, 0, -1, 1);
  }

  private void viewOrthoFixed() {
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glOrtho(0, 640, 480, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();
  }

  private void viewPerspective() {
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
  }

  public bool checkInField(vec2 p) {
    return _size.contains(p);
  }

  public bool checkInField(float x, float y) {
    return _size.contains(x, y);
  }

  public bool checkInField(vec3 p) {
    return (_size.contains(p.x, p.y) && fabs(p.z) < 1);
  }

  public const(vec2) size() const {
    return _size;
  }

  public Texture titleTexture() {
    return _titleTexture;
  }
}

public class Wall: OdeActor {
  public override void init(Object[] args) {
    super.init();
  }

  public override void move() {
  }

  public override void draw(mat4 view) {}
}

public class FloorWall: Wall {}
