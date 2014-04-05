/*
 * $Id: displaylist.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.displaylist;

private import derelict.opengl3.gl;
private import abagames.util.sdl.sdlexception;

/**
 * Manage a display list.
 */
public class DisplayList {
 private:
  bool registered;
  int num;
  int idx;
  int enumIdx;

  public this(int num) {
    this.num = num;
    idx = glGenLists(num);
  }

  public void beginNewList() {
    resetList();
    newList();
  }

  public void nextNewList() {
    glEndList();
    enumIdx++;
    if (enumIdx >= idx + num || enumIdx < idx)
      throw new SDLException("Can't create new list. Index out of bound.");
    glNewList(enumIdx, GL_COMPILE);
  }

  public void endNewList() {
    glEndList();
    registered = true;
  }

  public void resetList() {
    enumIdx = idx;
  }

  public void newList() {
    glNewList(enumIdx, GL_COMPILE);
  }

  public void endList() {
    glEndList();
    enumIdx++;
    registered = true;
  }

  public void call(int i = 0) {
    glCallList(idx + i);
  }

  public void close() {
    if (!registered)
      return;
    glDeleteLists(idx, num);
  }
}
