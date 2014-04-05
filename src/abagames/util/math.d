/*
 * $Id: math.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.math;

private import std.math;
private import abagames.util.vector;

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

  public static bool checkVectorHit(Vector tp, Vector p, Vector pp, float hitWidth) {
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
