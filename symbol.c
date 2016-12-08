#include <stdlib.h>
#include <string.h>
#include "symbol.h"

// open source hash table: http://troydhanson.github.io/uthash
#include "uthash.h"


extern LLVMModuleRef Module;

struct symbol_info {
  char         *name;
  int          isArg;
  LLVMValueRef val;
  UT_hash_handle  hh; // do not change this name
};

typedef struct scope_def
{
  struct scope_def * lower;
  struct symbol_info * map;
} scope_t;

scope_t *head=NULL;

void symbol_push_scope()
{
  scope_t *new_scope = (scope_t*) malloc (sizeof(scope_t));
  new_scope->lower = head;
  new_scope->map = NULL;
  head = new_scope;
}

void symbol_pop_scope()
{
  scope_t *old = head;
  head = head->lower;
  free(old);
}

int is_global_scope()
{
  return head==NULL;
}

void symbol_insert(const char* name, LLVMValueRef val, int isArg)
{
  struct symbol_info *si;

  if (head==NULL)
    return;

  si = (struct symbol_info*) malloc(sizeof(struct symbol_info));
  si->name = (char*)name;
  si->isArg = isArg;
  si->val = val;

  HASH_ADD_KEYPTR( hh, head->map, name, strlen(name), si );
}

struct symbol_info * get_symbol_in_scope(const char* name, scope_t *scope);

LLVMValueRef symbol_find(const char*name,int *isArg)
{
  struct symbol_info *si = get_symbol_in_scope(name,head);

  if (si)
    {
      *isArg = si->isArg;
      return si->val;
    }
  else
    {
      *isArg = 0;
      return LLVMGetNamedGlobal(Module,name);
    }
}

struct symbol_info * get_symbol_in_scope(const char *name, scope_t *scope)
{
  if (scope==NULL)
    {
      /* then must be global scope */
      return NULL;
    }

  struct symbol_info *si;

  HASH_FIND_STR(scope->map, name, si);  /* id already in the hash? */
  if (si==NULL) {
    scope = scope->lower;
    return get_symbol_in_scope(name,scope);
  }

  return si;
}
