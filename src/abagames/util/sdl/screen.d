/*
 * $Id: screen.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.screen;

private import gl3n.linalg;

/**
 * SDL screen handler interface.
 */
public interface Screen {
  public mat4 initSDL();
  public void closeSDL();
  public void flip();
  public void clear();
}

public interface SizableScreen {
  public bool windowMode();
  public int width();
  public int height();
}
