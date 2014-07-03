/*
 * $Id: math.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.math;

private import std.math;
private import gl3n.linalg;

/**
 * Math utility methods.
 */
public class Math {
 private:

  public static void normalizeDeg(ref float d) {
    if (d < -PI)
      d = PI * 2 - (-d % (PI * 2));
    d = (d + PI) % (PI * 2) - PI;
  }

  public static void normalizeDeg360(ref float d) {
    if (d < -180)
      d = 360 - (-d % 360);
    d = (d + 180) % 360 - 180;
  }

  public static bool checkVectorHit(vec2 tp, vec2 p, vec2 pp, float hitWidth) {
    float bmvx, bmvy, inaa;
    bmvx = pp.x;
    bmvy = pp.y;
    bmvx -= p.x;
    bmvy -= p.y;
    inaa = bmvx * bmvx + bmvy * bmvy;
    if (inaa > 0.00001) {
      float sofsx, sofsy, inab, hd;
      sofsx = tp.x;
      sofsy = tp.y;
      sofsx -= p.x;
      sofsy -= p.y;
      inab = bmvx * sofsx + bmvy * sofsy;
      if (inab >= 0 && inab <= inaa) {
        hd = sofsx * sofsx + sofsy * sofsy - inab * inab / inaa;
        if (hd >= 0 && hd <= hitWidth)
          return true;
      }
    }
    return false;
  }
}

real fastdist(vec2 v1, vec2 v2 = vec2(0)) {
  float ax = fabs(v1.x - v2.x);
  float ay = fabs(v1.y - v2.y);
  if (ax > ay)
    return ax + ay / 2;
  else
    return ay + ax / 2;
}

real fastdist(vec3 v1, vec3 v2 = vec3(0)) {
  float ax = fabs(v1.x - v2.x);
  float ay = fabs(v1.y - v2.y);
  float az = fabs(v1.z - v2.z);
  float axy;
  if (ax > ay)
    axy = ax + ay / 2;
  else
    axy = ay + ax / 2;
  if (axy > az)
    return axy + az / 2;
  else
    return az + axy / 2;
}

bool contains(vec2 v1, float x, float y, float r = 1) {
  if (x >= -v1.x * r && x <= v1.x * r && y >= -v1.y * r && y <= v1.y * r)
    return true;
  else
    return false;
}

bool contains(vec2 v1, vec2 v2, float r = 1) {
  return contains(v1, v2.x, v2.y, r);
}
