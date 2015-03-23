/*
 * $Id: screen3d.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.screen3d;

private import std.conv;
private import std.string;
private import derelict.sdl2.sdl;
private import gl3n.linalg;
private import abagames.util.support.gl;
private import abagames.util.sdl.screen;
private import abagames.util.sdl.sdlexception;

/**
 * SDL screen handler(3D, OpenGL).
 */
public class Screen3D: Screen, SizableScreen {
 private:
  static float _brightness = 1;
  float _farPlane = 1000;
  float _nearPlane = 0.1;
  int _width = 640;
  int _height = 480;
  bool _windowMode = false;
  SDL_Window* _window = null;

  protected abstract void init();
  protected abstract void close();

  public mat4 initSDL() {
    // Initialize Derelict.
    DerelictSDL2.load();
    loadGL(); // We use deprecated features.
    // Initialize SDL.
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
      throw new SDLInitFailedException(
        "Unable to initialize SDL: " ~ to!string(SDL_GetError()));
    }
    // Create an OpenGL screen.
    Uint32 videoFlags;
    int winheight = _height;
    int winwidth = _width;
    if (_windowMode) {
      videoFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE;
    } else {
      winheight = 0;
      winwidth = 0;
      videoFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP;
    }
    _window = SDL_CreateWindow("",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        winwidth, winheight, videoFlags);
    if (_window == null) {
      throw new SDLInitFailedException
        ("Unable to create SDL screen: " ~ to!string(SDL_GetError()));
    }
    SDL_Renderer* _renderer = SDL_CreateRenderer(_window, -1, 0);
    SDL_RendererInfo info;
    SDL_GetRendererInfo(_renderer, &info);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");
    SDL_RenderSetLogicalSize(_renderer, _width, _height);
    // Reload GL now to get any features.
    reloadGL();
    glViewport(0, 0, width, height);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    mat4 windowmat = resized(_width, _height);
    SDL_ShowCursor(SDL_DISABLE);
    init();
    return windowmat;
  }

  // Reset a viewport when the screen is resized.
  public mat4 screenResized() {
    glViewport(0, 0, _width, _height);
    glMatrixMode(GL_PROJECTION);
    mat4 view = setPerspective();
    glMatrixMode(GL_MODELVIEW);
    return view;
  }

  public mat4 setPerspective() {
    glLoadIdentity();
    //gluPerspective(45.0f, cast(GLfloat) width / cast(GLfloat) height, nearPlane, farPlane);
    const float ratio = cast(GLfloat) _height / cast(GLfloat) _width;
    glFrustum(-_nearPlane,
              _nearPlane,
              -_nearPlane * ratio,
              _nearPlane * ratio,
              0.1f, _farPlane);

    return mat4.perspective(
      -_nearPlane, _nearPlane,
      -_nearPlane * ratio, _nearPlane * ratio,
      0.1f, _farPlane);
  }

  public mat4 resized(int w, int h) {
    _width = w;
    _height = h;
    return screenResized();
  }

  public void closeSDL() {
    close();
    SDL_ShowCursor(SDL_ENABLE);
  }

  public void flip() {
    handleError();
    SDL_GL_SwapWindow(_window);
  }

  public void clear() {
    glClear(GL_COLOR_BUFFER_BIT);
  }

  public void handleError() {
    GLenum error = glGetError();
    if (error == GL_NO_ERROR)
      return;
    closeSDL();
    throw new Exception("OpenGL error(" ~ to!string(error) ~ ")");
  }

  protected void setCaption(string name) {
    SDL_SetWindowTitle(_window, std.string.toStringz(name));
  }

  public bool windowMode(bool v) {
    return _windowMode = v;
  }

  public bool windowMode() {
    return _windowMode;
  }

  public int width(int v) {
    return _width = v;
  }

  public int width() {
    return _width;
  }

  public int height(int v) {
    return _height = v;
  }

  public int height() {
    return _height;
  }

  public static void setColor(float r, float g, float b, float a = 1) {
    glColor4f(r * _brightness, g * _brightness, b * _brightness, a);
  }

  public static void setClearColor(float r, float g, float b, float a = 1) {
    glClearColor(r * _brightness, g * _brightness, b * _brightness, a);
  }

  public static float brightness(float v) {
    return _brightness = v;
  }

  public static float brightness() {
    return _brightness;
  }
}
