/*
 * $Id: actor.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.actor;

private import gl3n.linalg;

/**
 * Actor in the game that has the interface to move and draw.
 */
public class Actor {
 protected:
  bool _exists;
 private:

  public bool exists() nothrow {
    return _exists;
  }

  public bool exists(bool value) {
    return _exists = value;
  }

  public abstract void init(Object[] args);
  public abstract void close();
  public abstract void move();
  public abstract void draw(mat4 view);
}

/**
 * Object pooling for actors.
 */
public class ActorPool(T) {
 public:
  T[] actor;
 protected:
  size_t actorIdx = 0;
 private:

  public this() {}

  public this(int n, Object[] args = null) {
    createActors(n, args);
  }

  protected void createActors(int n, Object[] args = null) {
    actor = new T[n];
    foreach (ref T a; actor) {
      a = new T;
      a.exists = false;
      a.init(args);
    }
    actorIdx = 0;
  }

  public void close() {
    foreach (T ac; actor)
      ac.close();
  }

  public T getInstance() {
    for (size_t i = 0; i < actor.length; i++) {
      nextActor();
      if (!actor[actorIdx].exists)
        return actor[actorIdx];
    }
    return null;
  }

  public T getInstanceForced() nothrow {
    nextActor();
    return actor[actorIdx];
  }

  public T[] getMultipleInstances(int n) {
    T[] rsl;
    for (int i = 0; i < n; i++) {
      T inst = getInstance();
      if (!inst) {
        foreach (T r; rsl)
          r.exists = false;
        return null;
      }
      inst.exists = true;
      rsl ~= inst;
    }
    foreach (T r; rsl)
      r.exists = false;
    return rsl;
  }

  public void move() {
    foreach (T ac; actor)
      if (ac.exists)
        ac.move();
  }

  public void draw(mat4 view) {
    foreach (T ac; actor)
      if (ac.exists)
        ac.draw(view);
  }

  public void clear() {
    foreach (T ac; actor)
      ac.exists = false;
    actorIdx = 0;
  }

  private void nextActor() {
    if (actorIdx == 0)
      actorIdx = actor.length - 1;
    else
      actorIdx--;
  }
}
