/*
 * $Id: ship.d,v 1.3 2006/03/18 02:42:50 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.mcd.ship;

private import std.math;
private import std.typecons;
private import derelict.ode.ode;
private import gl3n.linalg;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.sdl.twinstickpad;
private import abagames.util.sdl.recordableinput;
private import abagames.util.ode.world;
private import abagames.util.ode.odeactor;
private import abagames.mcd.field;
private import abagames.mcd.gamemanager;
private import abagames.mcd.screen;
private import abagames.mcd.shot;
private import abagames.mcd.shape;
private import abagames.mcd.enemy;
private import abagames.mcd.particle;
private import abagames.mcd.bullet;
private import abagames.mcd.bullettarget;
private import abagames.mcd.bulletpool;
private import abagames.mcd.soundmanager;

/**
 * Player's ship.
 */
public class Ship: OdeActor, BulletTarget {
 private:
  static const int RESTART_CNT = 72;
  static const int FIRE_INTERVAL = 2;
  static const int FIRE_INTERVAL_MAX = 4;
  static const int SHOT_MAX_NUM = 15;
  static const int ENHANCED_SHOT_MAX_NUM = 24;
  static const int TAIL_MAX_NUM = 63;
  static const float SLIDE_FORCE_BASE = 10;
  static const float ANGULAR_FORCE_BASE = 10;
  static const float SIZE = 1.0f;
  static const float MASS = 3;
  static const float TURN_RATIO_BASE = 0.2f;
  static const float TURN_CHANGE_RATIO = 0.5f;
  static const float FIX_CHANGE_RATIO = 0.2f;
  static const float SLOW_VELOCITY_RATIO = 0.01f;
  static const float SLOW_ANGULAR_RATIO = 0.1f;
  static Rand rand;
  RecordableTwinStickPad pad;
  Field field;
  Screen screen;
  ParticlePool particles;
  ConnectedParticlePool connectedParticles;
  GameManager gameManager;
  BulletPool bullets;
  EnhancedShotPool enhancedShots;
  vec3 _pos;
  vec2 trgPos;
  vec2 slideVel;
  ShotPool shots;
  float deg;
  float trgDeg;
  mat4 rot;
  int restartCnt;
  int fireCnt;
  float fireInterval;
  ShipTail tails[TAIL_MAX_NUM];
  int tailNum;
  int enhancedShotCnt;
  ShapeGroup shape;
  LinePoint linePoint;
  Drawable subShape;
  bool aPressed, bPressed, gsaPressed;
  int bulletDisapCnt;
  int restartBulletDisapCnt;
  int titleCnt;
  bool _replayMode;

  invariant() {
    if (_pos && field) {
      assert(_pos.x > -field.size.x * 100);
      assert(_pos.x <  field.size.x * 100);
      assert(_pos.y > -field.size.y * 100);
      assert(_pos.y <  field.size.y * 100);
      assert(!_pos.z.isNaN);
      assert(!deg.isNaN);
    }
  }

  public static void init() {
    rand = new Rand;
    ShipTail.init();
    Shot.init();
    EnhancedShot.init();
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(World world, TwinStickPad pad, Field field, Screen screen,
              ParticlePool particles, ConnectedParticlePool connectedParticles,
              GameManager gameManager) {
    setWorld(world);
    this.pad = cast(RecordableTwinStickPad) pad;
    this.field = field;
    this.screen = screen;
    this.particles = particles;
    this.connectedParticles = connectedParticles;
    this.gameManager = gameManager;
    _pos = vec3(0);
    trgPos = vec3(0);
    slideVel = vec3(0);
    deg = 0;
    trgDeg = 0;
    Object[] sargs;
    sargs ~= field;
    sargs ~= particles;
    shots = new ShotPool(SHOT_MAX_NUM, sargs);
    shots.init(world);
    enhancedShots = new EnhancedShotPool(ENHANCED_SHOT_MAX_NUM, sargs);
    enhancedShots.init(world);
    shape = new ShapeGroup;
    shape.addShape(new Triangle(world, MASS, 0, 0, SIZE * 0.5f, SIZE));
    linePoint = new LinePoint(field);
    linePoint.setSpectrumParams(0, 1.0f, 0, 1.0f);
    subShape = new CenterShape;
    foreach (ref ShipTail t; tails)
      t = new ShipTail(world, field, this, particles, connectedParticles);
    super.init();
  }

  public void setBullets(BulletPool bullets) {
    this.bullets = bullets;
  }

  public override void init(Object[] args) {
    // Not called.
  }

  private void initMassAndGeom() {
    super.set();
    shape.setMass(this);
    shape.setGeom(this, world.space);
  }

  public void start() {
    initMassAndGeom();
    restart();
    _pos.z = 2;
    dBodySetPosition(_bodyId, _pos.x, _pos.y, _pos.z);
    restartCnt = 0;
    restartBulletDisapCnt = bulletDisapCnt = 0;
    titleCnt = 0;
    aPressed = bPressed = true;
  }

  private void restart() {
    fireCnt = 99999;
    fireInterval = 99999;
    tailNum = 0;
    enhancedShotCnt = 0;
    bulletDisapCnt = 200;
    restartBulletDisapCnt = bulletDisapCnt + 1;
    trgDeg = 0;
    trgPos.x = trgPos.y = 0;
    slideVel.x = slideVel.y = 0;
    reset();
    _pos.x = 0;
    _pos.y = 0;
    _pos.z = 5;
    deg = 0;
    dBodySetPosition(_bodyId, _pos.x, _pos.y, _pos.z);
    setDeg(deg);
  }

  public void clear() {
    shots.clear();
    enhancedShots.clear();
    removeAllTailsWithoutParticles();
    remove();
  }

  public override void move() {
    TwinStickPadState input;
    if (!_replayMode) {
      input = pad.getState(true);
    } else {
      try {
        input = pad.replay();
      } catch (NoRecordDataException e) {
        gameManager.restartTitle();
        return;
      }
    }
    if (gameManager.isGameOver) {
      if (input.button & TwinStickPadState.Button.A) {
        if (!aPressed)
          gameManager.backToTitle();
        aPressed = true;
      } else {
        aPressed = false;
      }
      return;
    }
    restartCnt--;
    if (restartCnt > 0)
      return;
    if (restartCnt == 0)
      restart();
    restartBulletDisapCnt--;
    dReal *p = dBodyGetPosition(_bodyId);
    _pos.x = p[0];
    _pos.y = p[1];
    _pos.z = p[2];
    if (input.button & TwinStickPadState.Button.B) {
      if (tailNum > 0 && !bPressed) {
        slowLinearVel(SLOW_VELOCITY_RATIO * 10);
        enhancedShotCnt = bulletDisapCnt = getMultiplier() * 5;
        restartBulletDisapCnt = 0;
        removeAllTails();
        SoundManager.playSe("breaktail.wav");
      }
      bPressed = true;
    } else {
      bPressed = false;
    }
    if (_pos.z < -1)
      input.clear();
    slideVel.x = input.left.x;
    slideVel.y = input.left.y;
    if (slideVel.magnitude > 1)
      slideVel *= 1. / slideVel.magnitude;
    slideVel *= SLIDE_FORCE_BASE;
    addForce(slideVel.x, slideVel.y);
    deg = getDeg();
    getRot(rot);
    Math.normalizeDeg(deg);
    float ad;
    bool adjustDeg = false;
    if ((input.button & TwinStickPadState.Button.A) ||
        (input.right.x != 0 || input.right.y != 0)) {
      fireInterval = FIRE_INTERVAL;
      if (!aPressed) {
        fireCnt = 0;
        aPressed = true;
        trgDeg = deg;
      }
      if (input.right.x != 0 || input.right.y != 0)
        trgDeg = atan2(-input.right.x, input.right.y);
      ad = trgDeg;
      adjustDeg = true;
    } else {
      aPressed = false;
      fireInterval *= 1.033f;
      if (fireInterval > FIRE_INTERVAL_MAX)
        fireInterval = 99999;
      if (slideVel.x != 0 || slideVel.y != 0) {
        ad = atan2(-slideVel.x, slideVel.y);
        Math.normalizeDeg(ad);
        adjustDeg = true;
      }
    }
    if (adjustDeg) {
      ad -= deg;
      Math.normalizeDeg(ad);
      float sf = fabs(ad) * 2;
      if (sf > 1)
        sf = 1;
      if (ad > 0.001f)
        addRelForceAtRelPos(0, SIZE * 0.5f, 0,  ANGULAR_FORCE_BASE * sf, 0, 0);
      else if (ad < -0.001f)
        addRelForceAtRelPos(0, SIZE * 0.5f, 0, -ANGULAR_FORCE_BASE * sf, 0, 0);
      deg += ad * 0.05f;
    }
    if (field.checkInField(_pos)) {
      setDeg(deg);
      linePoint.enableSpectrumColor = true;
    } else {
      linePoint.enableSpectrumColor = false;
    }
    addForce(0, 0, -Field.GRAVITY);
    slowLinearVel(SLOW_VELOCITY_RATIO);
    slowAngularVel(SLOW_ANGULAR_RATIO);
    if (_pos.z < -10)
      destroyed();
    if (fireCnt <= 0) {
      if (fabs(_pos.z) < 1)
        fireShot(deg);
      fireCnt = cast(int) fireInterval;
    }
    fireCnt--;
    shots.move();
    enhancedShots.move();
    for (int i = 0; i < tailNum; i++)
      tails[i].move();
    if (tailNum <= 0)
      TailParticle.setTarget(_pos, deg);
    else
      tails[tailNum-1].setTailParticleTarget();
    recordLinePoints();
    if (bulletDisapCnt > 0) {
      bulletDisapCnt--;
      bullets.collapseIntoParticle();
    }
    if (enhancedShotCnt > 0)
      enhancedShotCnt--;
  }

  private void fireShot(float deg) {
    if (enhancedShotCnt > 0) {
      EnhancedShot es = enhancedShots.getInstance();
      if (!es)
        return;
      es.set(_pos, deg);
      SoundManager.playSe("enhancedshot.wav");
    } else {
      Shot s = shots.getInstance();
      if (!s)
        return;
      s.set(_pos, deg);
      SoundManager.playSe("shot.wav");
    }
  }

  public override void clearContactJoint() {
    super.clearContactJoint();
    foreach (ShipTail ss; tails)
      ss.clearContactJoint();
  }

  public void addTail(float size) {
    if (restartCnt > 0 || !field.checkInField(_pos))
      return;
    if (tailNum <= 0) {
      float id = (SIZE + size) * ShipTail.TAIL_INTERVAL;
      tails[0].set(_pos.x + sin(deg) * id, _pos.y - cos(deg) * id, _pos.z, deg, size, _bodyId);
      tailNum++;
      SoundManager.playSe("addtail.wav");
    } else if (tailNum < TAIL_MAX_NUM) {
      if (tails[tailNum - 1].addTail(tails[tailNum], size)) {
        tailNum++;
        SoundManager.playSe("addtail.wav");
      }
    }
  }

  public override void collide(OdeActor actor, ref bool hasCollision, ref bool checkFeedback) {
    hasCollision = checkFeedback = false;
    if (cast(Wall) actor)
      hasCollision = true;
  }

  private void destroyed() {
    if (restartCnt > 0)
      return;
    gameManager.shipDestroyed();
    for (int i = 0; i < 16; i++)
      addConnectedParticles(_pos, rand.nextSignedFloat(PI), 0.25f + rand.nextFloat(3));
    for (int i = 0; i < 64; i++) {
      Particle p = particles.getInstanceForced();
      float d = rand.nextSignedFloat(PI);
      float v = 0.1f + rand.nextFloat(0.3f);
      p.set(_pos, -sin(d) * v, cos(d) * v, 0.4f + rand.nextFloat(0.4f),
            0.25f + rand.nextFloat(0.25f), 0.75f + rand.nextFloat(0.25f), 0.25f + rand.nextFloat(0.25f));
    }
    removeAllTails();
    restartCnt = RESTART_CNT;
    SoundManager.playSe("shipdestroyed.wav");
  }

  private void removeAllTails() {
    for (int i = 0; i < tailNum; i++)
      tails[i].remove();
    tailNum = 0;
  }

  private void removeAllTailsWithoutParticles() {
    for (int i = 0; i < tailNum; i++)
      tails[i].removeWithoutParticles();
    tailNum = 0;
  }

  public void moveInTitle() {
    titleCnt++;
    float tcr = cast(float) (titleCnt % 600) / 600;
    if (tcr < 0.3f) {
      _pos.x = (tcr - 0.15f) / 0.15f * field.size.x;
      _pos.y = -field.size.y;
    } else if (tcr < 0.5f) {
      _pos.x = field.size.x;
      _pos.y = (tcr - 0.4f) / 0.1f * field.size.y;
    } else if (tcr < 0.8f) {
      _pos.x = -(tcr - 0.65f) / 0.15f * field.size.x;
      _pos.y = field.size.y;
    } else {
      _pos.x = -field.size.x;
      _pos.y = -(tcr - 0.9f) / 0.1f * field.size.y;
    }
    _pos.z = 5;
    dBodySetPosition(_bodyId, _pos.x, _pos.y, _pos.z);
    TailParticle.setTarget(_pos, deg);
    restartCnt = RESTART_CNT;
  }

  public void addConnectedParticles(vec3 p, float deg, float speed = 1) {
    ConnectedParticle[] cps = connectedParticles.getMultipleInstances(9);
    if (!cps)
      return;
    float d = deg - PI / 8;
    ConnectedParticle pcp = null;
    int c = 60 + rand.nextInt(120);
    foreach (ConnectedParticle cp; cps) {
      cp.set(p.x, p.y, p.z, d, (0.2f + rand.nextSignedFloat(0.08f)) * speed,
             0.25f + rand.nextFloat(0.25f), 0.75f + rand.nextFloat(0.25f), 0.25f + rand.nextFloat(0.25f),
             c, rand.nextFloat(2), pcp, true);
      d += PI / 4 / 8 + rand.nextSignedFloat(PI / 4 / 8 / 4);
      pcp = cp;
    }
  }

  public int getMultiplier() {
    return tailNum + 1;
  }

  public bool inRestartBulletDisap() {
    return (restartBulletDisapCnt > 0);
  }

  public void recordLinePoints() {
    mat4 model = rot;
    model.translate(_pos.x, _pos.y, _pos.z);

    linePoint.beginRecord(model);
    shape.recordLinePoints(linePoint);
    linePoint.endRecord();
  }

  public override void draw(mat4 view) {
    shots.draw(view);
    enhancedShots.draw(view);
    if (restartCnt > 0)
      return;
    for (int i = 0; i < tailNum; i++)
      tails[i].draw(view);
    linePoint.drawSpectrum(view);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    shape.drawShadow(view, linePoint);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    linePoint.draw(view);

    mat4 model = mat4.identity;
    model = model * rot;
    model.translate(_pos.x, _pos.y, _pos.z);
    subShape.setModelMatrix(model);

    subShape.draw(view);
  }

  public void drawLeft(mat4 view, float x, float y) {
    mat4 model = mat4.identity();
    model.rotate(-PI, vec3(0, 0, 1));
    model.scale(15, 15, 15);
    model.translate(x, y, 0);
    subShape.setModelMatrix(model);

    linePoint.beginRecord(model);
    shape.recordLinePoints(linePoint);
    linePoint.endRecord();
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    shape.drawShadow(view, linePoint);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    linePoint.draw(view);

    subShape.draw(view);
  }

  public vec3 pos() {
    return _pos;
  }

  public vec2 getTargetPos() {
    trgPos.x = _pos.x;
    trgPos.y = _pos.y;
    return trgPos;
  }

  public bool replayMode(bool v) {
    return _replayMode = v;
  }

  public bool replayMode() {
    return _replayMode;
  }
}

/**
 * Ship's tails.
 */
public class ShipTail: OdeActor {
 public:
  static const float WIDTH = 0.25f;
  static const float COLOR_R = 0.1f;
  static const float COLOR_G = 0.4f;
  static const float COLOR_B = 0.2f;
  static const float TAIL_INTERVAL = 0.57f;
 private:
  static const float SIZE = 1.0f;
  static const float MASS = 0.1f;
  static Rand rand;
  vec3 _pos;
  float deg;
  mat4 rot;
  vec3 size;
  Field field;
  Ship ship;
  ParticlePool particles;
  ConnectedParticlePool connectedParticles;
  dMass m;
  Shape shape;
  LinePoint linePoint;
  dJointID joint;

  invariant() {
    if (_pos) {
      assert(!_pos.x.isNaN);
      assert(!_pos.y.isNaN);
      assert(!_pos.z.isNaN);
      assert(!deg.isNaN);
      assert(size.x >= 0);
      assert(size.y >= 0);
      assert(size.z >= 0);
    }
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(World world, Field field, Ship ship,
              ParticlePool particles, ConnectedParticlePool connectedParticles) {
    setWorld(world);
    this.field = field;
    this.ship = ship;
    this.particles = particles;
    this.connectedParticles = connectedParticles;
    _pos = vec3(0);
    size = vec3(0);
    deg = 0;
    shape = new Square(world, MASS, 0, 0, SIZE * WIDTH, SIZE);
    linePoint = new LinePoint(field);
    linePoint.setSpectrumParams(COLOR_R, COLOR_G, COLOR_B, 0.6f);
    linePoint.alpha = 0.5f;
    super.init();
  }

  public override void init(Object[] args) {
    // Not called.
  }

  private void initMassAndGeom() {
    super.set();
    dMassSetZero(&m);
    shape.addMass(&m, Nullable!vec3(size));
    setMass(m);
    shape.addGeom(this, world.space, Nullable!vec3(size));
  }

  public void set(float x, float y, float z, float deg, float sz, dBodyID jointedBodyId) {
    size.x = size.y = sz;
    size.z = 1;
    initMassAndGeom();
    _pos.x = x;
    _pos.y = y;
    _pos.z = z;
    dBodySetPosition(_bodyId, _pos.x, _pos.y, _pos.z);
    this.deg = deg;
    setDeg(deg);
    joint = dJointCreateHinge(World.world, cast(dJointGroupID) 0);
    dJointSetHingeParam(joint, dParamLoStop, -1);
    dJointSetHingeParam(joint, dParamHiStop, 1);
    dJointAttach(joint, _bodyId, jointedBodyId);
    dJointSetHingeAnchor(joint, x - sin(deg) * SIZE / 2, y + cos(deg) * SIZE / 2, 0);
    dJointSetHingeAxis(joint, 0, 0, 1);
    linePoint.init();
  }

  public override void move() {
    dReal *p = dBodyGetPosition(_bodyId);
    _pos.x = p[0];
    _pos.y = p[1];
    _pos.z = p[2];
    deg = getDeg();
    getRot(rot);
    addForce(0, 0, -Field.GRAVITY * 0.1f);
    if (field.checkInField(_pos)) {
      setDeg(deg);
      linePoint.enableSpectrumColor = true;
    } else {
      linePoint.enableSpectrumColor = false;
    }
    recordLinePoints();
  }

  public override void remove() {
    dJointDestroy(joint);
    super.remove();
    ship.addConnectedParticles(_pos, deg + PI / 2);
    ship.addConnectedParticles(_pos, deg - PI / 2);
  }

  public void removeWithoutParticles() {
    dJointDestroy(joint);
    super.remove();
  }

  public override void collide(OdeActor actor, ref bool hasCollision, ref bool checkFeedback) {
    hasCollision = checkFeedback = false;
    if (cast(Wall) actor || cast(ShipTail) actor || cast(Ship) actor)
      hasCollision = true;
  }

  public void setTailParticleTarget() {
    TailParticle.setTarget(_pos, deg);
  }

  public bool addTail(ShipTail tail, float sz) {
    if (fabs(_pos.z) >= 1)
      return false;
    float id = (size.x + sz) * TAIL_INTERVAL;
    tail.set(_pos.x + sin(deg) * id, _pos.y - cos(deg) * id, _pos.z, deg, sz, _bodyId);
    return true;
  }

  public void recordLinePoints() {
    mat4 model = mat4.identity;
    model.scale(size.x, size.y, size.z);
    model = model * rot;
    model.translate(_pos.x, _pos.y, _pos.z);

    linePoint.beginRecord(model);
    shape.recordLinePoints(linePoint);
    linePoint.endRecord();
  }

  public override void draw(mat4 view) {
    linePoint.drawSpectrum(view);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    shape.drawShadow(view, linePoint);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    linePoint.draw(view);
  }

  public vec3 pos() {
    return _pos;
  }
}
