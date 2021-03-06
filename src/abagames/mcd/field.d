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
private import abagames.util.sdl.shaderprogram;
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
  static ShaderProgram fieldProgram;
  static GLuint fieldVao;
  static GLuint fieldVbo;
  static ShaderProgram letterProgram;
  static GLuint letterVao;
  static GLuint letterVbo;
  static ShaderProgram overlayProgram;
  static GLuint overlayVao;
  static GLuint overlayVbo;
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
    eyePosSize = _size - vec2(12, 9);
    _titleTexture = new Texture("title.bmp", 0, 0, 5, 1, 64, 64, 4278190080u);
    floorWall = new FloorWall;
    floorWall.setWorld(world);
    floorWall.init(null);

    if (fieldProgram !is null) {
      return;
    }

    fieldProgram = new ShaderProgram;
    fieldProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 size;\n"
      "uniform float xFactor;\n"
      "uniform float yFactor;\n"
      "\n"
      "attribute float z;\n"
      "attribute float color;\n"
      "\n"
      "varying float f_color;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(size * vec2(xFactor, yFactor), z, 1);\n"
      "  f_color = color;\n"
      "}\n"
    );
    fieldProgram.setFragmentShader(
      "uniform float brightness;\n"
      "\n"
      "varying float f_color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(vec3(f_color * brightness), 1);\n"
      "}\n"
    );
    GLint zLoc = 0;
    GLint colorLoc = 1;
    fieldProgram.bindAttribLocation(zLoc, "z");
    fieldProgram.bindAttribLocation(colorLoc, "color");
    fieldProgram.link();
    fieldProgram.use();

    glGenBuffers(1, &fieldVbo);
    glGenVertexArrays(1, &fieldVao);

    static const float[] FIELD_BUF = [
      /*
      z,  color */
       0, 1,
      -8, 0.4f
    ];
    enum FIELD_Z = 0;
    enum FIELD_COLOR = 1;
    enum FIELD_BUFSZ = 2;

    glBindVertexArray(fieldVao);

    glBindBuffer(GL_ARRAY_BUFFER, fieldVbo);
    glBufferData(GL_ARRAY_BUFFER, FIELD_BUF.length * float.sizeof, FIELD_BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(zLoc, 1, FIELD_BUFSZ, FIELD_Z);
    glEnableVertexAttribArray(zLoc);

    vertexAttribPointer(colorLoc, 1, FIELD_BUFSZ, FIELD_COLOR);
    glEnableVertexAttribArray(colorLoc);

    letterProgram = new ShaderProgram;
    letterProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 pos;\n"
      "uniform float width;\n"
      "\n"
      "attribute vec2 factor;\n"
      "attribute vec2 tex;\n"
      "\n"
      "varying vec2 f_tc;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(pos + factor * width, 0, 1);\n"
      "  f_tc = tex;\n"
      "}\n"
    );
    letterProgram.setFragmentShader(
      "uniform sampler2D sampler;\n"
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "varying vec2 f_tc;\n"
      "\n"
      "void main() {\n"
      "  vec4 texColor = texture2D(sampler, f_tc);\n"
      "  vec4 color4 = vec4(color * vec3(brightness), 1);\n"
      "  gl_FragColor = texColor * color4;\n"
      "}\n"
    );
    GLint factorLoc = 0;
    GLint texLoc = 1;
    letterProgram.bindAttribLocation(factorLoc, "factor");
    letterProgram.bindAttribLocation(texLoc, "tex");
    letterProgram.link();
    letterProgram.use();

    letterProgram.setUniform("sampler", 0);

    glGenBuffers(1, &letterVbo);
    glGenVertexArrays(1, &letterVao);

    static const float[] LETTER_BUF = [
      /*
      factor,       tex */
      -0.5f, -0.5f, 0, 0,
       0.5f, -0.5f, 1, 0,
       0.5f,  0.5f, 1, 1,
      -0.5f,  0.5f, 0, 1
    ];
    enum LETTER_FACTOR = 0;
    enum LETTER_TEX = 2;
    enum LETTER_BUFSZ = 4;

    glBindVertexArray(letterVao);

    glBindBuffer(GL_ARRAY_BUFFER, letterVbo);
    glBufferData(GL_ARRAY_BUFFER, LETTER_BUF.length * float.sizeof, LETTER_BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(factorLoc, 2, LETTER_BUFSZ, LETTER_FACTOR);
    glEnableVertexAttribArray(factorLoc);

    vertexAttribPointer(texLoc, 2, LETTER_BUFSZ, LETTER_TEX);
    glEnableVertexAttribArray(texLoc);

    overlayProgram = new ShaderProgram;
    overlayProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform float factor;\n"
      "\n"
      "attribute vec2 pos;\n"
      "attribute vec2 diff;\n"
      "attribute float mult;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(pos + factor * mult * diff, 0, 1);\n"
      "}\n"
    );
    overlayProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    GLint posLoc = 0;
    GLint diffLoc = 1;
    GLint multLoc = 2;
    overlayProgram.bindAttribLocation(posLoc, "pos");
    overlayProgram.bindAttribLocation(diffLoc, "diff");
    overlayProgram.bindAttribLocation(multLoc, "mult");
    overlayProgram.link();
    overlayProgram.use();

    glGenBuffers(1, &overlayVbo);
    glGenVertexArrays(1, &overlayVao);

    static const float[] OVERLAY_BUF = [
      /*
      pos,      diff,    mult, padding */
      370, 466,  0,  7, -1,    0, 0, 0,
      370, 466,  0,  7,  1,    0, 0, 0,
      615, 466,  0,  7, -1,    0, 0, 0,
      615, 466,  0,  7,  1,    0, 0, 0,
      631, 450,  7,  0, -1,    0, 0, 0,
      631, 450,  7,  0,  1,    0, 0, 0,
      631,  30,  7,  0, -1,    0, 0, 0,
      631,  30,  7,  0,  1,    0, 0, 0,
      615,  14,  0, -7, -1,    0, 0, 0,
      615,  14,  0, -7,  1,    0, 0, 0,
       25,  14,  0, -7, -1,    0, 0, 0,
       25,  14,  0, -7,  1,    0, 0, 0,
        9,  30, -7,  0, -1,    0, 0, 0,
        9,  30, -7,  0,  1,    0, 0, 0,
        9, 450, -7,  0, -1,    0, 0, 0,
        9, 450, -7,  0,  1,    0, 0, 0,
       25, 466,  0,  7, -1,    0, 0, 0,
       25, 466,  0,  7,  1,    0, 0, 0,
      270, 466,  0,  7, -1,    0, 0, 0,
      270, 466,  0,  7,  1,    0, 0, 0
    ];
    enum OVERLAY_POS = 0;
    enum OVERLAY_DIFF = 2;
    enum OVERLAY_MULT = 4;
    enum OVERLAY_BUFSZ = 8;

    glBindVertexArray(overlayVao);

    glBindBuffer(GL_ARRAY_BUFFER, overlayVbo);
    glBufferData(GL_ARRAY_BUFFER, OVERLAY_BUF.length * float.sizeof, OVERLAY_BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(posLoc, 2, OVERLAY_BUFSZ, OVERLAY_POS);
    glEnableVertexAttribArray(posLoc);

    vertexAttribPointer(diffLoc, 2, OVERLAY_BUFSZ, OVERLAY_DIFF);
    glEnableVertexAttribArray(diffLoc);

    vertexAttribPointer(multLoc, 1, OVERLAY_BUFSZ, OVERLAY_MULT);
    glEnableVertexAttribArray(multLoc);
  }

  public void close() {
    if (fieldProgram !is null) {
      glDeleteVertexArrays(1, &fieldVao);
      glDeleteBuffers(1, &fieldVbo);
      fieldProgram.close();
      fieldProgram = null;

      glDeleteVertexArrays(1, &letterVao);
      glDeleteBuffers(1, &letterVbo);
      letterProgram.close();
      letterProgram = null;

      glDeleteVertexArrays(1, &overlayVao);
      glDeleteBuffers(1, &overlayVbo);
      overlayProgram.close();
      overlayProgram = null;
    }
  }

  public void start() {
    floorWall.set(false);
    ShapeGroup s = new ShapeGroup;
    s.addShape(new Square(world, 9999999, 0, 0, -6, _size.x * 2, _size.y * 2, 10));
    s.addGeom(floorWall, world.space);
    cnt = 0;
    eyePos = vec2(0);
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
    vec2 t = ship.pos;
    if (checkInField(ship.pos)) {
      if (t.x < -eyePosSize.x)
        t.x = -eyePosSize.x;
      else if (t.x > eyePosSize.x)
        t.x = eyePosSize.x;
      if (t.y < -eyePosSize.y)
        t.y = -eyePosSize.y;
      else if (t.y > eyePosSize.y)
        t.y = eyePosSize.y;
    }
    eyePos += (t - eyePos) * 0.05f;
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
    for (int z = 0; z > -8; z--) {
      float a = 1;
      if (z < 0)
        a = 0.8f + z * 0.05f;
      drawSquare(view, -_size.x, -_size.y, _size.x * 2, _size.y * 2, z, a);
    }
    for (float w = 0.98f; w < 1.0f; w += 0.0033f)
      drawSquare(view, -_size.x * w, -_size.y * w, _size.x * w * 2, _size.y * w * 2, 0, 0.9f);

    fieldProgram.use();

    fieldProgram.setUniform("projmat", view);
    fieldProgram.setUniform("brightness", Screen.brightness);
    fieldProgram.setUniform("size", _size);

    fieldProgram.useVao(fieldVao);

    for (float x = -0.9f; x < 1.0f; x += 0.1f) {
      fieldProgram.setUniform("xFactor", x);

      fieldProgram.setUniform("yFactor", -1.);
      glDrawArrays(GL_LINES, 0, 2);

      fieldProgram.setUniform("yFactor", 1.);
      glDrawArrays(GL_LINES, 0, 2);
    }

    for (float y = -1; y < 1.1f; y += 0.1f) {
      fieldProgram.setUniform("yFactor", y);

      fieldProgram.setUniform("xFactor", -1.);
      glDrawArrays(GL_LINES, 0, 2);

      fieldProgram.setUniform("xFactor", 1.);
      glDrawArrays(GL_LINES, 0, 2);
    }
  }

  private void drawSquare(mat4 view, float x, float y, float w, float h, float z, float a) {
    Screen.drawLine(view, x, y, z, x + w, y, z, a);
    Screen.drawLine(view, x + w, y, z, x + w, y + h, z, a);
    Screen.drawLine(view, x + w, y + h, z, x, y + h, z, a);
    Screen.drawLine(view, x, y + h, z, x, y, z, a);
  }

  public void drawOverlay(mat4 view) {
    gameManager.drawState(view);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    overlayProgram.use();

    overlayProgram.setUniform("projmat", view);
    overlayProgram.setUniform("brightness", Screen.brightness);

    overlayProgram.useVao(overlayVao);

    for (int i = 0; i < 9; i++) {
      static GLuint[4] ELEM;

      ELEM[0] = 2 * i + 0;
      ELEM[1] = 2 * i + 2;
      ELEM[2] = 2 * i + 3;
      ELEM[3] = 2 * i + 1;

      overlayProgram.setUniform("color", 1, 0, 0);
      overlayProgram.setUniform("factor", 1f);
      glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_INT, ELEM.ptr);

      overlayProgram.setUniform("color", 1, 1, 1);
      overlayProgram.setUniform("factor", 0.5f);
      glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_INT, ELEM.ptr);
    }

    float x = 285, y = 465;
    float lsz = 26, lof = 20;

    drawLogo(view, x, y, lsz, lof);
  }

  public void drawLogo(mat4 view, float x, float y, float lsz, float lof, bool drawOutline = true) {
    glEnable(GL_TEXTURE_2D);

    letterProgram.use();

    letterProgram.setUniform("projmat", view);

    glActiveTexture(GL_TEXTURE0);
    letterProgram.useVao(letterVao);

    for (int i = 0; i < 5; i++) {
      letterProgram.setUniform("brightness", 1.);
      letterProgram.setUniform("color", 1, 1, 1);
      _titleTexture.bindMask(i);

      glBlendFunc(GL_DST_COLOR, GL_ZERO);
      drawLetter(x, y, lsz);

      glBlendFunc(GL_ONE, GL_ONE);
      letterProgram.setUniform("brightness", Screen.brightness);
      _titleTexture.bind(i);

      if (drawOutline) {
        letterProgram.setUniform("color", 1, 0, 0);
        drawLetter(x, y, lsz);
      }

      letterProgram.setUniform("color", 1, 1, 1);
      drawLetter(x, y, lsz);

      if (i == 0)
        x += lof * 1.0f;
      else
        x += lof * 0.9f;
    }

    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glDisable(GL_TEXTURE_2D);
  }

  public void drawLetter(float cx, float cy, float width) {
    letterProgram.setUniform("pos", cx, cy);
    letterProgram.setUniform("width", width);

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
  }

  public mat4 fixedOrthoView() {
    // TODO: Remove the 640x480 assumption.
    return mat4.orthographic(0, 640, 480, 0, -1, 1);
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
