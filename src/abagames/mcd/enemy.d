/*
 * $Id: enemy.d,v 1.3 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.enemy;

private import std.math;
private import std.typecons;
private import derelict.ode.ode;
private import gl3n.linalg;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.ode.odeactor;
private import abagames.util.ode.world;
private import abagames.mcd.field;
private import abagames.mcd.screen;
private import abagames.mcd.ship;
private import abagames.mcd.shot;
private import abagames.mcd.shape;
private import abagames.mcd.particle;
private import abagames.mcd.spec;
private import abagames.mcd.bullet;
private import abagames.mcd.bulletpool;
private import abagames.mcd.barrage;
private import abagames.mcd.gamemanager;
private import abagames.mcd.soundmanager;

/**
 * Enemies (centipedes and blocks).
 */
public class Enemy: OdeActor {
 private:
  static Rand rand;
  Field field;
  ParticlePool particles;
  ConnectedParticlePool connectedParticles;
  TailParticlePool tailParticles;
  NumIndicatorPool numIndicators;
  Ship ship;
  GameManager gameManager;
  EnemySpec spec;
  EnemyState state;
  vec3 lastForce;

  invariant() {
    if (state && state.pos) {
      assert(!state.pos.x.isNaN);
      assert(!state.pos.y.isNaN);
      assert(!state.pos.z.isNaN);
    }
    if (lastForce) {
      assert(!lastForce.x.isNaN);
      assert(!lastForce.y.isNaN);
      assert(!lastForce.z.isNaN);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void init(Object[] args) {
    super.init(true);
    field = cast(Field) args[0];
    particles = cast(ParticlePool) args[1];
    connectedParticles = cast(ConnectedParticlePool) args[2];
    tailParticles = cast(TailParticlePool) args[3];
    numIndicators = cast(NumIndicatorPool) args[4];
    ship = cast(Ship) args[5];
    gameManager = cast(GameManager) args[6];
    state = new EnemyState(args);
    lastForce = vec3(0);
  }

  public bool set(EnemySpec spec, float x, float y, float z, float deg,
                  Nullable!vec3 sizeScale = Nullable!vec3(),
                  float massScale = 1,
                  int type = 0) {
    if (!sizeScale.isNull)
      return set(spec, x, y, z, deg, sizeScale.x, sizeScale.y, sizeScale.z, massScale, type);
    else
      return set(spec, x, y, z, deg, 1, 1, 1, massScale, type);
  }

  public bool set(EnemySpec spec, float x, float y, float z, float deg,
                  float sx, float sy, float sz,
                  float massScale = 1,
                  int type = 0) {
    super.set();
    this.spec = spec;
    state.clear();
    state.pos.x = x;
    state.pos.y = y;
    state.pos.z = z;
    state.deg = deg;
    state.sizeScale.x = sx;
    state.sizeScale.y = sy;
    state.sizeScale.z = sz;
    state.massScale = massScale;
    state.type = type;
    lastForce.x = lastForce.y = lastForce.z = 0;
    dBodySetPosition(_bodyId, x, y, z);
    if (spec.rotate2d)
      setDeg(deg);
    spec.initState(this, state);
    state.linePoint.alpha = 0;
    state.linePoint.alphaTrg = 1;
    return true;
  }

  public void setJointedEnemies(Enemy[] enemies) {
    state.jointedEnemies = enemies;
  }

  public void setJointedEnemiesPrevNext(Enemy pe, Enemy ne) {
    state.prevJointedEnemy = pe;
    state.nextJointedEnemy = ne;
  }

  public void setJoints(dJointID[] joints) {
    state.joints = joints;
  }

  public override void move() {
    if (checkDestroyed())
      return;
    updateState();
    if (!spec.move(this, state)) {
      remove();
      return;
    }
    vec3 f = getForce();
    lastForce.x = f.x;
    lastForce.y = f.y;
    lastForce.z = f.z;
    if (spec.rotate2d && field.checkInField(state.pos))
      setDeg(state.deg);
    spec.recordLinePoints(state, state.linePoint);
  }

  public override void remove() {
    removeCleaning();
    super.remove();
  }

  public void removeAsTail(int idx) {
    TailParticle tp = tailParticles.getInstance();
    if (tp)
      tp.set(state.pos.x, state.pos.y, state.pos.z, state.sizeScale.x,
             spec.colorR, spec.colorG, spec.colorB,
             cast(int) (30 + 30.0f / (idx + 1)));
    (cast(ConnectedParticlesBodyAddable) spec).addConnectedParticlesBody(this, state);
    remove();
  }

  private void removeCleaning() {
    state.removeAllJoints();
    if (state.topBullet) {
      state.topBullet.removeForced();
      state.topBullet = null;
    }
  }

  public void updateState() {
    dReal *p = dBodyGetPosition(_bodyId);
    state.pos.x = p[0];
    state.pos.y = p[1];
    state.pos.z = p[2];
    state.deg = getDeg();
    getRot(state.rot);
    dReal* lv = getLinearVel();
    dReal* av = getAngularVel();
    for (int i = 0; i < 3; i++) {
      state.linearVel[i] = lv[i];
      state.angularVel[i] = av[i];
    }
    if (state.topBullet) {
      state.topBullet.bullet.pos.x = state.pos.x;
      state.topBullet.bullet.pos.y = state.pos.y;
      if (state.setTopBulletDirection)
        state.topBullet.bullet.deg = state.deg;
      if (state.setPlumbDirection) {
        float td = atan2(-ship.pos.x + state.pos.x, ship.pos.y - state.pos.y);
        Math.normalizeDeg(td);
        if (td < -PI * 3 / 4)
          td = PI;
        else if (td < -PI / 4)
          td = -PI / 2;
        else if (td < PI / 4)
          td = 0;
        else if (td < PI * 3 / 4)
          td = PI / 2;
        else
          td = PI;
        state.topBullet.bullet.deg = td;
      }
    }
  }

  public override void collide(OdeActor actor, ref bool hasCollision, ref bool checkFeedback) {
    hasCollision = checkFeedback = false;
    if (!exists)
      return;
    Enemy ce = cast(Enemy) actor;
    if (ce)
      if (ce is state.prevJointedEnemy || ce is state.nextJointedEnemy)
        return;
    if (cast(SimpleBullet) actor)
      return;
    hasCollision = true;
    checkFeedback = true;
    spec.collide(this, state, actor);
  }

  public override void checkFeedbackForce() {
    if (contactJointNum <= 0)
      return;
    getFeedbackForce();
    for (int i = 0; i < contactJointNum; i++) {
      ContactJoint* cj = &(contactJoint[i]);
      vec3 ff = cj.feedbackForce;
      ff.x += lastForce.x * 0.9f;
      ff.y += lastForce.y * 0.9f;
      int pn = cast(int) ((fabs(ff.x) + fabs(ff.y)) * 0.01f);
      float bv = pn * 0.1f;
      if (pn <= 0)
        continue;
      if (pn > 3)
        pn = 3;
      float pd = atan2(-ff.x, ff.y) + PI;
      for (int j = 0; j < pn; j++) {
        Particle p = particles.getInstanceForced();
        float d = pd + PI + rand.nextSignedFloat(1.0f);
        float v = bv * (1 + rand.nextSignedFloat(0.3f));
        p.set(cj.pos, -sin(d) * v, cos(d) * v, 0.3f + rand.nextFloat(0.3f),
              0.3f, 0.3f + rand.nextFloat(0.3f), 0.4f + rand.nextFloat(0.4f), 30 + rand.nextInt(10));
      }
    }
  }

  private bool checkDestroyed() {
    if (state.destroyable && state.pos.z < -10) {
      removeCleaning();
      removeBodyAndGeom();
      spec.destroyed(this, state);
      removeExistence();
      SoundManager.playSe("destroyed.wav");
      return true;
    }
    return false;
  }

  public void addScore(int sc, float sz = 0.5f) {
    gameManager.addScore(sc * ship.getMultiplier());
    NumIndicator ni = numIndicators.getInstance();
    if (!ni)
      return;
    float vx = 0, vy = 0;
    if (state.pos.x < -field.size.x)
      vx = 1;
    else if (state.pos.x > field.size.x)
      vx = -1;
    if (state.pos.y < -field.size.y)
      vy = 1;
    else if (state.pos.y > field.size.y)
      vy = -1;
    if (vx != 0 && vy != 0) {
      vx *= 0.8f;
      vy *= 0.6f;
    }
    ni.set(sc, ship.getMultiplier(), state.pos.x, state.pos.y, vx * 0.3f, vy * 0.3f, sz);
  }

  public void addConnectedParticles(float deg, float speed = 1, bool rot = true) {
    ConnectedParticle[] cps = connectedParticles.getMultipleInstances(9);
    if (!cps)
      return;
    float d = deg - PI / 8;
    ConnectedParticle pcp = null;
    int c = 60 + rand.nextInt(60);
    foreach (ConnectedParticle cp; cps) {
      cp.set(state.pos.x, state.pos.y, state.pos.z,
             d, (0.2f + rand.nextSignedFloat(0.08f)) * speed,
             0.75f + rand.nextFloat(0.25f), 0.25f + rand.nextFloat(0.75f), 0,
             c, 1, pcp, true);
      if (rot)
        cp.setRot(state.rot);
      d += PI / 4 / 8 + rand.nextSignedFloat(PI / 4 / 8 / 4);
      pcp = cp;
    }
  }

  public vec3 pos() {
    return state.pos;
  }

  public void drawSpectrum(mat4 view) {
    state.linePoint.drawSpectrum(view);
  }

  public bool collideBullet() nothrow {
    return spec.collideBullet;
  }

  public void drawShadow(mat4 view) {
    spec.drawShadow(view, state.linePoint);
  }

  public override void draw(mat4 view) {
    state.linePoint.draw(view);
    spec.drawSubShape(view, state);
  }

  public EnemyState getState() {
    return state;
  }

  public bool isCentipedeHead() {
    if (cast(CentHead) spec)
      return true;
    else
      return false;
  }

  public bool isBlock() {
    if (cast(Block) spec)
      return true;
    else
      return false;
  }

  public void slowdown() {
    state.slowdown();
  }
}

public class EnemyPool: OdeActorPool!(Enemy) {
  public this(int n, Object[] args) {
    super(n, args);
  }

  public void drawShadow(mat4 view) {
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    foreach (Enemy e; actor)
      if (e.exists)
        e.drawShadow(view);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
  }

  public void drawSpectrum(mat4 view) {
    foreach (Enemy e; actor)
      if (e.exists)
        e.drawSpectrum(view);
  }

  public bool exists() {
    foreach (Enemy e; actor)
      if (e.exists)
        return true;
    return false;
  }

  public int countCentipedes() {
    int c = 0;
    foreach (Enemy e; actor)
      if (e.exists && e.isCentipedeHead)
        c++;
    return c;
  }

  public int countBlocks() {
    int c = 0;
    foreach (Enemy e; actor)
      if (e.exists && e.isBlock)
        c++;
    return c;
  }

  public void slowdown() {
    foreach (Enemy e; actor)
      if (e.exists)
        e.slowdown();
  }
}

/**
 * Holding a state of an enemy.
 */
public class EnemyState {
 public:
  vec3 pos;
  float deg;
  mat4 rot;
  dReal[3] linearVel;
  dReal[3] angularVel;
  Nullable!vec3 sizeScale;
  float massScale;
  bool destroyable;
  int cnt;
  int trgDeg;
  int turnCnt;
  int moveFlag;
  bool isHead;
  int type;
  float forwardForceScale;
  float slowVelocityRatio;
  Enemy[] jointedEnemies;
  Enemy prevJointedEnemy;
  Enemy nextJointedEnemy;
  dJointID[] joints;
  Barrage barrage;
  BulletActor topBullet;
  bool setTopBulletDirection;
  bool setPlumbDirection;
  LinePoint linePoint;
 private:
  static const int MAX_LINE_POINT_NUM = 24;
  Field field;

  invariant() {
    assert(!pos.x.isNaN);
    assert(!pos.y.isNaN);
    assert(!pos.z.isNaN);
    assert(!fabs(linearVel[0]).isNaN);
    assert(!fabs(linearVel[1]).isNaN);
    assert(!fabs(linearVel[2]).isNaN);
    assert(!fabs(angularVel[0]).isNaN);
    assert(!fabs(angularVel[1]).isNaN);
    assert(!fabs(angularVel[2]).isNaN);
    assert(!deg.isNaN);
    if (!sizeScale.isNull) {
      assert(sizeScale.x > 0);
      assert(sizeScale.y > 0);
      assert(sizeScale.z > 0);
    }
    assert(massScale > 0);
    assert(forwardForceScale > 0);
    assert(slowVelocityRatio > 0);
  }

  public this(Object[] args) {
    field = cast(Field) args[0];
    pos = vec3(0);
    sizeScale = vec3(0);
    linePoint = new LinePoint(field, MAX_LINE_POINT_NUM);
    barrage = new Barrage;
    clearState();
  }

  private void clearState() {
    pos.x = pos.y = pos.z = 0;
    deg = 0;
    rot = mat4.identity;
    for (int i = 0; i < 3; i++)
      linearVel[i] = angularVel[i] = 0;
    sizeScale.x = sizeScale.y = sizeScale.z = 1;
    massScale = 1;
    destroyable = true;
    cnt = 0;
    trgDeg = 0;
    turnCnt = 0;
    moveFlag = 0;
    isHead = false;
    type = 0;
    forwardForceScale = 1;
    slowVelocityRatio = 1;
    jointedEnemies = null;
    prevJointedEnemy = nextJointedEnemy = null;
    joints = null;
    barrage.clear();
    topBullet = null;
    setTopBulletDirection = false;
    setPlumbDirection = false;
    linePoint.init();
  }

  public void clear() {
    clearState();
  }

  public void removeAllJoints() {
    if (joints)
      foreach (dJointID j; joints)
        dJointDestroy(j);
    joints = null;
  }

  public void slowdown() {
    forwardForceScale *= 0.5f;
    if (topBullet)
      topBullet.slowdown();
  }
}

/**
 * Base class of an enemy's specification.
 */
public class EnemySpec {
 protected:
  static Rand rand;
  Field field;
  Ship ship;
  BulletPool bullets;
  World world;
  ShapeGroup shape;
  Drawable subShape = null;
  bool _rotate2d = true;
  bool _collideBullet = false;
  float _colorR, _colorG, _colorB;

  public static this() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public void initState(Enemy enemy, EnemyState state) {
    shape.setMass(enemy, state.sizeScale, state.massScale);
    shape.setGeom(enemy, world.space, state.sizeScale);
  }

  public abstract bool move(Enemy enemy, EnemyState state);

  public void destroyed(Enemy enemy, EnemyState state) {}

  public void collide(Enemy enemy, EnemyState state, OdeActor actor) nothrow {}

  public void recordLinePoints(EnemyState state, LinePoint lp) {
    mat4 model = mat4.identity;
    model.scale(state.sizeScale.x, state.sizeScale.y, state.sizeScale.z);
    model = model * state.rot;
    model.translate(state.pos.x, state.pos.y, state.pos.z);

    lp.beginRecord(model);
    shape.recordLinePoints(lp);
    lp.endRecord();
  }

  public void drawShadow(mat4 view, LinePoint lp) {
    shape.drawShadow(view, lp);
  }

  public void drawSubShape(mat4 view, EnemyState state) {}

  public bool rotate2d() {
   return _rotate2d;
  }

  public bool collideBullet() nothrow {
   return _collideBullet;
  }

  public float colorR() {
    return _colorR;
  }

  public float colorG() {
    return _colorG;
  }

  public float colorB() {
    return _colorB;
  }
}

/**
 * Set multiple enemies' instances for a jointed enemy.
 */
public interface JointedEnemySpec {
  public Enemy setJointedEnemies(EnemyPool enemies, float x, float y, float z, float deg);
}
