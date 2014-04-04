/*
 * $Id: prefmanager.d,v 1.1.1.1 2006/02/19 04:57:26 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.prefmanager;

/**
 * Save/load the preference(e.g. high-score).
 */
public interface PrefManager {
  public void save();
  public void load();
}
