#if defined _mynatives_included_
  #endinput
#endif
#define _mynatives_included_

native int Id_CalcRank(int xp);
native int Id_GetId(int client);
native int Id_SetXP(int client, int xp);
native int Id_GetXP(int client);
native int Id_AddXP(int client, int amount);