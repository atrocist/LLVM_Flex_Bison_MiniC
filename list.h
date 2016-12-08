#ifndef LIST_H
#define LIST_H

#include <unistd.h>
#include "llvm-c/Core.h"

typedef struct paramlist_def {
  struct paramlist_def *next;
  const char * name;
  LLVMTypeRef  type;
} paramlist_t;

paramlist_t* push_param(paramlist_t *head, const char *name, LLVMTypeRef type);
paramlist_t* pop_param(paramlist_t *head);
paramlist_t* next_param(paramlist_t *head);
int paramlist_size(paramlist_t *head);

void push_loop(LLVMBasicBlockRef expr,
	       LLVMBasicBlockRef body,
	       LLVMBasicBlockRef reinit,
	       LLVMBasicBlockRef exit);

void pop_loop();

typedef struct loop_info {
  LLVMBasicBlockRef expr;
  LLVMBasicBlockRef body;
  LLVMBasicBlockRef reinit;
  LLVMBasicBlockRef exit;
} loop_info_t;

loop_info_t get_loop();


#endif /*LIST_H*/
