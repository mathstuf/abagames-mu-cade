/*
 * $Id: odeactor.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.util.ode.odeactor;

private import std.math;
private import derelict.ode.ode;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.ode.world;

/**
 * Actor working with ODE.
 */
public class OdeActor: Actor {
 public:
  static bool collided;
 protected:
  struct ContactJoint {
    dJointID jointID;
    int bodyIdx;
    vec3 pos;
    vec3 feedbackForce;
  };
  World world;
  dBodyID _bodyId;
  dGeomID[] geomId;
  int geomNum = 0;
  ContactJoint[] contactJoint;
  int contactJointNum = 0;
  bool bodyCreated;
 private:
  static vec3 vvct, force;
  static const float VELOCITY_DECAY_RATIO = 0.1f;
  static const int GEOM_NUM = 8;
  static const int CONTACT_JOINT_NUM = 16;

  public static void initFirst() {
    vvct = vec3(0);
    force = vec3(0);
  }

  public void setWorld(World world) {
    this.world = world;
  }

  public void init(bool checkFeedback = false) {
    geomId = new dGeomID[GEOM_NUM];
    if (checkFeedback) {
      contactJoint = new ContactJoint[CONTACT_JOINT_NUM];
      foreach (ref ContactJoint cj; contactJoint) {
        cj.pos = vec3(0);
        cj.feedbackForce = vec3(0);
      }
    }
    bodyCreated = false;
  }

  public override void close() {
  }

  public void set(bool withBody = true) {
    if (withBody)
      createBody();
    else
      world.storeOdeActor(cast(dBodyID) 0, this);
    geomNum = 0;
    clearContactJoint();
    _exists = true;
  }

  public void remove() {
    removeBodyAndGeom();
    removeExistence();
  }

  public void removeBodyAndGeom() {
    if (!_exists)
      return;
    destroyGeom();
    destroyBody();
  }

  public void removeExistence() {
    if (!_exists)
      return;
    _exists = false;
  }

  private void createBody() {
    _bodyId = world.bodyCreate(this);
    bodyCreated = true;
    // Set body params.
    dBodySetGravityMode(_bodyId, 0);
  }

  private void destroyBody() {
    if (!bodyCreated)
      return;
    world.bodyDestroy(_bodyId);
    bodyCreated = false;
  }

  public void setMass(dMass mass) {
    dBodySetMass(_bodyId, &mass);
  }

  public void addGeom(dGeomID gi) {
    if (geomNum >= GEOM_NUM)
      return;
    if (bodyCreated)
      dGeomSetBody(gi, _bodyId);
    geomId[geomNum] = gi;
    geomNum++;
  }

  private void destroyGeom() {
    for (int i = 0; i < geomNum; i++)
      dGeomDestroy(geomId[i]);
  }

  public void addForce(float vx = 0, float vy = 0, float vz = 0) {
    dBodyAddForce(_bodyId, vx, vy, vz);
  }

  public void addRelForce(float vx = 0, float vy = 0, float vz = 0) {
    dBodyAddRelForce(_bodyId, vx, vy, vz);
  }

  public void addRelForceAtRelPos(float vx, float vy, float vz, float ox, float oy, float oz) {
    dBodyAddRelForceAtRelPos(_bodyId, vx, vy, vz, ox, oy, oz);
  }

  public void addTorque(float tx = 0, float ty = 0, float tz = 0) {
    dBodyAddForce(_bodyId, tx, ty, tz);
  }

  public vec3 getForce() {
    dReal* f = dBodyGetForce(_bodyId);
    force = vec3(f[0], f[1], f[2]);
    return force;
  }

  public void reset() {
    resetLinearVel();
    resetAngularVel();
    resetForce();
    resetTorque();
  }

  public dReal* getLinearVel() {
    return dBodyGetLinearVel(_bodyId);
  }

  public void setLinearVel(dReal *vel) {
    dBodySetLinearVel(_bodyId, vel[0], vel[1], vel[2]);
  }

  public dReal* getAngularVel() {
    return dBodyGetAngularVel(_bodyId);
  }

  public void setAngularVel(dReal *vel) {
    dBodySetAngularVel(_bodyId, vel[0], vel[1], vel[2]);
  }

  public void resetLinearVel() {
    dBodySetLinearVel(_bodyId, 0, 0, 0);
  }

  public void resetAngularVel() {
    dBodySetAngularVel(_bodyId, 0, 0, 0);
  }

  public void resetForce() {
    dBodySetForce(_bodyId, 0, 0, 0);
  }

  public void resetTorque() {
    dBodySetTorque(_bodyId, 0, 0, 0);
  }

  public void slowLinearVel(float ratio = VELOCITY_DECAY_RATIO) {
    dReal *vm = dBodyGetLinearVel(_bodyId);
    vvct = vec3(vm[0], vm[1], vm[2]);
    vvct *= (1 - ratio);
    dBodySetLinearVel(_bodyId, vvct.x, vvct.y, vvct.z);
  }

  public void limitLinearVel(float max, float ratio = VELOCITY_DECAY_RATIO) {
    dReal *vm = dBodyGetLinearVel(_bodyId);
    vvct = vec3(vm[0], vm[1], vm[2]);
    float vs = vvct.magnitude;
    if (vs > max) {
      float p = 1 + (max / vs - 1) * ratio;
      vvct *= p;
      dBodySetLinearVel(_bodyId, vvct.x, vvct.y, vvct.z);
    }
  }

  public void slowAngularVel(float ratio = VELOCITY_DECAY_RATIO) {
    dReal *vm = dBodyGetAngularVel(_bodyId);
    vvct = vec3(vm[0], vm[1], vm[2]);
    vvct *= (1 - ratio);
    dBodySetAngularVel(_bodyId, vvct.x, vvct.y, vvct.z);
  }

  public void limitAngularVel(float max, float ratio = VELOCITY_DECAY_RATIO) {
    dReal *vm = dBodyGetAngularVel(_bodyId);
    vvct = vec3(vm[0], vm[1], vm[2]);
    float vs = vvct.magnitude;
    if (vs > max) {
      float p = 1 + (max / vs - 1) * ratio;
      vvct *= p;
      dBodySetAngularVel(_bodyId, vvct.x, vvct.y, vvct.z);
    }
  }

  public void enableBody() {
    dBodyEnable(_bodyId);
  }

  public void disableBody() {
    dBodyDisable(_bodyId);
  }

  public void setDeg(float d) {
    dReal[12] matrix;
    matrix[0] = cos(d);
    matrix[1] = -sin(d);
    matrix[2] = 0;
    matrix[3] = 0;
    matrix[4] = sin(d);
    matrix[5] = cos(d);
    matrix[6] = 0;
    matrix[7] = 0;
    matrix[8] = 0;
    matrix[9] = 0;
    matrix[10] = 1;
    matrix[11] = 0;
    dBodySetRotation(_bodyId, matrix);
  }

  public float getDeg() {
    dReal* matrix;
    matrix = dBodyGetRotation(_bodyId);
    float d1 = atan2(-matrix[1], matrix[0]);
    float d2 = atan2(matrix[4], matrix[5]);
    return (d1 + d2) / 2;
  }

  public void getRot(ref mat4 matrix) {
    dReal* rot = dBodyGetRotation(_bodyId);
    matrix[0][0]= rot[0];
    matrix[1][0]= rot[4];
    matrix[2][0]= rot[8];
    matrix[3][0]= 0;
    matrix[0][1]= rot[1];
    matrix[1][1]= rot[5];
    matrix[2][1]= rot[9];
    matrix[3][1]= 0;
    matrix[0][2]= rot[2];
    matrix[1][2]= rot[6];
    matrix[2][2]= rot[10];
    matrix[3][2]= 0;
    matrix[0][3]= 0;
    matrix[1][3]= 0;
    matrix[2][3]= 0;
    matrix[3][3]= 1;
  }

  public void setRot(mat4 rot) {
    dReal[12] matrix;
    matrix[0]= rot[0][0];
    matrix[1]= rot[1][0];
    matrix[2]= rot[2][0];
    matrix[3]= 0;
    matrix[4]= rot[0][1];
    matrix[5]= rot[1][1];
    matrix[6]= rot[2][1];
    matrix[7]= 0;
    matrix[8]= rot[0][2];
    matrix[9]= rot[1][2];
    matrix[10]= rot[2][2];
    matrix[11]= 0;
    dBodySetRotation(_bodyId, matrix);
  }

  public void collide(OdeActor actor, ref bool hasCollision, ref bool checkFeedback) nothrow {
    hasCollision = checkFeedback = false;
  }

  public void clearContactJoint() {
    contactJointNum = 0;
  }

  public void addContactJoint(float x, float y, float z, dJointID id, int bodyIdx) nothrow {
    if (contactJointNum >= CONTACT_JOINT_NUM)
      return;
    ContactJoint* cj = &(contactJoint[contactJointNum]);
    cj.pos = vec3(x, y, z);
    cj.jointID = id;
    cj.bodyIdx = bodyIdx;
    contactJointNum++;
  }

  public void checkFeedbackForce() {}

  protected void getFeedbackForce() {
    for (int i = 0; i < contactJointNum; i++) {
      dJointFeedback* fb = dJointGetFeedback(contactJoint[i].jointID);
      vec3 ff = contactJoint[i].feedbackForce;
      ff.clear(0);
      if (contactJoint[i].bodyIdx == 1) {
        ff = vec3(fb.f1[0], fb.f1[1], fb.f1[2]);
      } else {
        ff = vec3(fb.f2[0], fb.f2[1], fb.f2[2]);
      }
    }
  }

  public bool checkCollide() {
    collided = false;
    for (int i = 0; i < geomNum; i++) {
      dSpaceCollide2(geomId[i], cast(dGeomID) world.space, cast(void*) 0, &checkCollideNearCallback);
      if (collided)
        break;
    }
    return collided;
  }

  protected void doCollide() {
    for (int i = 0; i < geomNum; i++)
      dSpaceCollide2(geomId[i], cast(dGeomID) world.space, cast(void*) 0, &nearCallback);
  }

  public dBodyID bodyId() {
    return _bodyId;
  }
}

public class OdeActorPool(T): ActorPool!(T) {
 private:

  public this(int n, Object[] args) {
    super(n, args);
  }

  public void init(World world) {
    foreach (T a; actor)
      a.setWorld(world);
  }

  public void clearContactJoint() {
    foreach (T a; actor)
      if (a.exists)
        a.clearContactJoint();
  }

  public void checkFeedbackForce() {
    foreach (T a; actor)
      if (a.exists)
        a.checkFeedbackForce();
  }

  public override void clear() {
    foreach (T a; actor)
      if (a.exists)
        a.remove();
    actorIdx = 0;
  }
}

extern (C) {
  void checkCollideNearCallback (void *data, dGeomID o1, dGeomID o2) nothrow {
    OdeActor.collided = true;
  }
}
