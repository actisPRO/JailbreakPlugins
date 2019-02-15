#if defined _mynatives_included_
  #endinput
#endif
#define _mynatives_included_

native int Achivements_GetValue(char[] steamid, char[] index);
native int Achivements_SetValue(char[] steamid, char[] index, int newValue);