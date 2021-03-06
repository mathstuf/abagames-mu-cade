/*
 * $Id: screen.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.screen;

private import gl3n.linalg;
private import abagames.util.support.gl;
private import abagames.util.sdl.screen3d;
private import abagames.util.sdl.shaderprogram;
private import abagames.mcd.field;

/**
 * OpenGL screen.
 */
public class Screen: Screen3D {
 private:
  static const string CAPTION = "Mu-cade";
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  Field field;

  protected override void init() {
    setCaption(CAPTION);
    glLineWidth(1);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glEnable(GL_BLEND);
    static if (!usingGLES) {
      // TODO: Implement in the shaders?
      glEnable(GL_LINE_SMOOTH);
    }
    glDisable(GL_TEXTURE_2D);
    static if (!usingGLES) {
      glDisable(GL_COLOR_MATERIAL);
      glDisable(GL_LIGHTING);
    }
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    setClearColor(0, 0, 0, 1);

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec3 start;\n"
      "uniform vec3 end;\n"
      "\n"
      "attribute float ratio;\n"
      "attribute float colorFactor;\n"
      "\n"
      "varying float f_colorFactor;\n"
      "\n"
      "void main() {\n"
      "  vec3 pos = start * (1. - ratio) + end * ratio;\n"
      "  gl_Position = projmat * vec4(pos, 1);\n"
      "  f_colorFactor = colorFactor;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float alpha;\n"
      "uniform float brightness;\n"
      "\n"
      "varying float f_colorFactor;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(vec3(f_colorFactor * alpha * brightness), 1);\n"
      "}\n"
    );
    GLint ratioLoc = 0;
    GLint colorFactorLoc = 1;
    program.bindAttribLocation(ratioLoc, "ratio");
    program.bindAttribLocation(colorFactorLoc, "colorFactor");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] BUF = [
      /*
      ratio, colorFactor */
      0,    1,
      0.5f, 0.5f,
      1,    1
    ];
    enum RATIO = 0;
    enum COLORFACTOR = 1;
    enum BUFSZ = 2;

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    vertexAttribPointer(ratioLoc, 1, BUFSZ, RATIO);
    glEnableVertexAttribArray(ratioLoc);

    vertexAttribPointer(colorFactorLoc, 1, BUFSZ, COLORFACTOR);
    glEnableVertexAttribArray(colorFactorLoc);
  }

  public mat4 setField(Field field) {
    this.field = field;
    return screenResized();
  }

  protected override void close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
    program.close();
  }

  public static void drawLine(mat4 view,
                              float x1, float y1, float z1,
                              float x2, float y2, float z2, float a = 1) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("start", x1, y1, z1);
    program.setUniform("end", x2, y2, z2);
    program.setUniform("alpha", a);
    program.setUniform("brightness", Screen.brightness);

    program.useVao(vao);
    glDrawArrays(GL_LINE_STRIP, 0, 3);
  }

  public override mat4 screenResized() {
    mat4 view = super.screenResized();
    float lw = (cast(float) width / 640 + cast(float) height / 480) / 2;
    if (lw < 1)
      lw = 1;
    else if (lw > 4)
      lw = 4;
    glLineWidth(lw);
    glViewport(0, 0, width, height);
    if (field)
      view = field.setLookAt();
    return view;
  }
}
