/*
 * $Id: screen.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.screen;

private import opengl;
private import openglu;
private import abagames.util.sdl.screen3d;
private import abagames.mcd.field;

/**
 * OpenGL screen.
 */
public class Screen: Screen3D {
 private:
  const char[] CAPTION = "Mu-cade";
  Field field;

  protected void init() {
    setCaption(CAPTION);
    glLineWidth(1);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glEnable(GL_BLEND);
    glEnable(GL_LINE_SMOOTH);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_COLOR_MATERIAL);
    glDisable(GL_LIGHTING);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    setClearColor(0, 0, 0, 1);
  }

  public void setField(Field field) {
    this.field = field;
    screenResized();
  }

  protected void close() {}

  public static void drawLine(float x1, float y1, float z1,
                              float x2, float y2, float z2, float a = 1) {
    Screen.setColor(a, a, a);
    glVertex3f(x1, y1, z1);
    Screen.setColor(a * 0.5f, a * 0.5f, a * 0.5f);
    glVertex3f((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2);
    glVertex3f((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2);
    Screen.setColor(a, a, a);
    glVertex3f(x2, y2, z2);
  }

  public static void setColorForced(float r, float g, float b, float a = 1) {
    glColor4f(r, g ,b, a);
  }

  public override void screenResized() {
    super.screenResized();
    float lw = (cast(float) width / 640 + cast(float) height / 480) / 2;
    if (lw < 1)
      lw = 1;
    else if (lw > 4)
      lw = 4;
    glLineWidth(lw);
    glViewport(0, 0, width, height);
    if (field)
      field.setLookAt();
  }
}
