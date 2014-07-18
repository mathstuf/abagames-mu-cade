/*
 * $Id: gl.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.support.gl;

version (Android) {
  private import derelict.gles.egl;
  public import derelict.gles.gles2;
  private import derelict.gles.ext2;

  public enum usingGLES = true;
} else {
  public import derelict.opengl3.gl;

  public enum usingGLES = false;
}

private import gl3n.linalg;
private import std.stdio;
private import std.conv;

public void loadGL() {
  version (Android) {
    DerelictEGL.load();
    DerelictGLES2.load();
  } else {
    DerelictGL.load();
  }
}

public void reloadGL() {
  version (Android) {
    DerelictGLES2.reload();

    if (!GL_OES_vertex_array_object) {
      throw new Exception("error: required GLES extension GL_OES_vertex_array_object not supported");
    }
  } else {
    DerelictGL.reload();
  }
}

version (Android) {
  public void glGenVertexArrays(GLsizei n, GLuint* arrays) {
    glGenVertexArraysOES(n, arrays);
  }

  public void glBindVertexArray(GLuint array) {
    glBindVertexArrayOES(array);
  }

  public void glDeleteVertexArrays(GLsizei n, GLuint* arrays) {
    glDeleteVertexArraysOES(n, arrays);
  }
}

public void checkMatrix(mat4 mat) {
  mat4 glm;
  mat4 glp;

  glGetFloatv(GL_MODELVIEW_MATRIX, glm.value_ptr);
  glGetFloatv(GL_PROJECTION_MATRIX, glp.value_ptr);
  glm.transpose;
  glp.transpose;

  writeln("gl : " ~ to!string(glp * glm));
  writeln("mat: " ~ to!string(mat));
}
