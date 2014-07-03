/*
 * $Id: gamemanager.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.gamemanager;

private import gl3n.linalg;
private import abagames.util.prefmanager;
private import abagames.util.sdl.mainloop;
private import abagames.util.sdl.screen;
private import abagames.util.sdl.input;

/**
 * Manage the lifecycle of the game.
 */
public class GameManager {
 protected:
  MainLoop mainLoop;
  Screen abstScreen;
  Input input;
  PrefManager abstPrefManager;
 private:

  public void setMainLoop(MainLoop mainLoop) {
    this.mainLoop = mainLoop;
  }

  public void setUIs(Screen screen, Input input) {
    abstScreen = screen;
    this.input = input;
  }

  public void setPrefManager(PrefManager prefManager) {
    abstPrefManager = prefManager;
  }

  public abstract void init();
  public abstract void start();
  public abstract void close();
  public abstract void move();
  public abstract void draw();
}
