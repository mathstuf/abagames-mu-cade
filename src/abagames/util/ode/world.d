/*
 * $Id: world.d,v 1.2 2006/02/22 22:27:47 kenta Exp $
 *
 * Copyright 2006 Kenta Cho. Some rights reserved.
 */
module abagames.util.ode.world;

private import ode.ode;
private import abagames.util.ode.odeactor;

/**
 * World for an ODE lib.
 */
public class World {
 public:
  static dWorldID world;
  static dJointGroupID contactGroup;
  static OdeActor[dBodyID] actor;
  static dJointFeedback[] jointFeedback;
  static int jointFeedbackIdx;
 private:
  const int MAX_CONTACTS = 4;
  static const int CONTACT_JOINT_GROUP_NUM = 1000;
  static const int CONTACT_JOINT_FEEDBACK_NUM = 100;
  static const dReal CONTACT_MAX_CORRECTING_VEL = 2.5;
  static const dReal CONTACT_SURFACE_LAYER = 0.01;
  dSpaceID _space;
  bool initialized = false;

  public void init() {
    world = dWorldCreate();
    dWorldSetContactMaxCorrectingVel(world, CONTACT_MAX_CORRECTING_VEL);
    dWorldSetContactSurfaceLayer (world, CONTACT_SURFACE_LAYER);
    _space = dHashSpaceCreate(cast(dSpaceID) 0);
    contactGroup = dJointGroupCreate(CONTACT_JOINT_GROUP_NUM);
    jointFeedback = new dJointFeedback[CONTACT_JOINT_FEEDBACK_NUM];
    actor = null;
    resetJointFeedback();
    initContacts();
    initialized = true;
  }

  public void close() {
    if (!initialized)
      return;
    dJointGroupDestroy(contactGroup);
    dSpaceDestroy(_space);
    dWorldDestroy(world);
    dCloseODE();
    initialized = false;
  }

  public void move(double step) {
    dSpaceCollide(_space, cast(void*) 0, &nearCallback);
    dWorldQuickStep(world, step);
  }

  public void resetJointFeedback() {
    jointFeedbackIdx = 0;
  }

  public void removeAllContactJoints() {
    dJointGroupEmpty(contactGroup);
  }

  public void setGravity(dReal x, dReal y, dReal z) {
    dWorldSetGravity(world, x, y, z);
  }

  public void createPlane(dReal a, dReal b, dReal c, dReal d) {
    dCreatePlane(_space, a, b, c, d);
  }

  public dBodyID bodyCreate(OdeActor oa) {
    dBodyID id = dBodyCreate(world);
    storeOdeActor(id, oa);
    return id;
  }

  public void storeOdeActor(dBodyID id, OdeActor oa) {
    actor[id] = oa;
  }

  public void bodyDestroy(dBodyID id) {
    actor.remove(id);
    dBodyDestroy(id);
  }

  public dSpaceID space() {
    return _space;
  }
}

extern (C) {
  dContact contact[World.MAX_CONTACTS];

  void initContacts() {
    for (int i = 0; i < World.MAX_CONTACTS; i++) {
      contact[i].surface.mode = 0;
      contact[i].surface.mu = 0;
    }
  }

  void nearCallback (void *data, dGeomID o1, dGeomID o2) {
    dBodyID b1, b2;
    b1 = dGeomGetBody(o1);
    b2 = dGeomGetBody(o2);
    if (b1 == b2)
      return;
    OdeActor a1, a2;
    a1 = World.actor[b1];
    a2 = World.actor[b2];
    bool hc1, hc2, cf1, cf2;
    a1.collide(a2, hc1, cf1);
    a2.collide(a1, hc2, cf2);
    if (!hc1 && !hc2)
      return;
    int numc = dCollide(o1, o2, World.MAX_CONTACTS, &(contact[0].geom), dContact.sizeof);
    for (int i = 0; i < numc; i++) {
      dJointID c = dJointCreateContact(World.world, World.contactGroup, &(contact[i]));
      dJointAttach(c, b1, b2);
      if (World.jointFeedbackIdx >= World.CONTACT_JOINT_FEEDBACK_NUM)
        continue;
      if (cf1 || cf2) {
        dJointSetFeedback(c, &(World.jointFeedback[World.jointFeedbackIdx]));
        World.jointFeedbackIdx++;
      }
      if (cf1)
        a1.addContactJoint(contact[i].geom.pos[0],
                           contact[i].geom.pos[1],
                           contact[i].geom.pos[2],
                           c, 1);
      if (cf2)
        a2.addContactJoint(contact[i].geom.pos[0],
                           contact[i].geom.pos[1],
                           contact[i].geom.pos[2],
                           c, 2);
    }
  }
}
