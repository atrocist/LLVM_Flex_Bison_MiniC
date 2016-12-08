#include "list.h"
#include "stdlib.h"

paramlist_t* push_param(paramlist_t *head, const char *name, LLVMTypeRef type)
{
  paramlist_t * node = (paramlist_t*) malloc(sizeof(paramlist_t));
  node->next = head;
  node->name = name;
  node->type = type;
  return node;
}


paramlist_t* pop_param(paramlist_t *head)
{
  paramlist_t *next = head->next;
  free(head);
  return next;
}

paramlist_t* next_param(paramlist_t *head)
{
  paramlist_t *next = head->next;
  return next;
}

int paramlist_size(paramlist_t *head)
{
  int cnt=0;
  while(head)
    {
      cnt++;
      head=head->next;
    }
  
  return cnt;
}

typedef struct loop_list {
  loop_info_t info;
  struct loop_list *next;
} loop_list_t;

static loop_list_t *head = NULL;

void push_loop(LLVMBasicBlockRef expr,
	       LLVMBasicBlockRef body,
	       LLVMBasicBlockRef reinit,
	       LLVMBasicBlockRef exit)
{
  loop_list_t *new = (loop_list_t*) malloc(sizeof(loop_list_t));

  new->info.expr=expr;
  new->info.body=body;
  new->info.reinit=reinit;
  new->info.exit=exit;

  new->next = head;
  head = new;
}

void pop_loop()
{
  loop_list_t *tmp = head;
  head = head->next;
  free(tmp);
}

loop_info_t get_loop()
{
  loop_info_t empty;
  empty.expr=NULL;
  empty.body=NULL;
  empty.reinit=NULL;
  empty.exit=NULL;

  if (head)
    return head->info;
  else
    return empty;
}
