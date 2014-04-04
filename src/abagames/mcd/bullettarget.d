/*
 * $Id: bullettarget.d,v 1.2 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.bullettarget;

private import abagames.util.vector;

/**
 * Target that is aimed by bullets.
 */
public interface BulletTarget {
 public:
  Vector getTargetPos();
}
