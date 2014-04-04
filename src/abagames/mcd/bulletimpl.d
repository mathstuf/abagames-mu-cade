/*
 * $Id: bulletimpl.d,v 1.2 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.bulletimpl;

private import bulletml;
private import abagames.util.bulletml.bullet;
private import abagames.mcd.bullet;
private import abagames.mcd.bullettarget;

/**
 * Bullet params of parsers, shape, the vertical/horizontal reverse moving,
 * target and rootBullet.
 */
public class BulletImpl: Bullet {
 public:
  ParserParam[] parserParam;
  int parserIdx;
  float xReverse, yReverse;
  BulletTarget target;
  BulletActor rootBullet;
 private:

  public this(int id) {
    super(id);
  }

  public void setParamFirst(ParserParam[] parserParam,
                            float xReverse, float yReverse,
                            BulletTarget target, BulletActor rootBullet) {
    this.parserParam = parserParam;
    this.xReverse = xReverse;
    this.yReverse = yReverse;
    this.target = target;
    this.rootBullet = rootBullet;
    parserIdx = 0;
  }

  public void setParam(BulletImpl bi) {
    parserParam = bi.parserParam;
    xReverse = bi.xReverse;
    yReverse = bi.yReverse;
    target = bi.target;
    rootBullet = null;
    parserIdx = bi.parserIdx;
  }

  public bool gotoNextParser() {
    parserIdx++;
    if (parserIdx >= parserParam.length) {
      parserIdx--;
      return false;
    } else {
      return true;
    }
  }

  public BulletMLParser* getParser() {
    return parserParam[parserIdx].parser;
  }

  public void resetParser() {
    parserIdx = 0;
  }

  public override float rank() {
    ParserParam pp = parserParam[parserIdx];
    float r = pp.rank;
    if (r > 1)
      r = 1;
    return r;
  }

  public float getSpeedRank() {
    return parserParam[parserIdx].speed;
  }

  public void slowdown() {
    foreach (ParserParam pp; parserParam)
      pp.speed *= 0.5f;
  }
}

public class ParserParam {
 public:
  BulletMLParser *parser;
  float rank;
  float speed;

  invariant {
    assert(rank >= 0 && rank <= 1);
    assert(speed > 0 && speed < 10);
  }

  public this(BulletMLParser *p, float r, float s) {
    parser = p;
    rank = r;
    speed = s;
  }
}
