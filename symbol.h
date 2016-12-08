#ifndef SYMBOL_H
#define SYMBOL_H

#include "llvm-c/Core.h"

void symbol_push_scope();
void symbol_pop_scope();

int is_global_scope();

void symbol_insert(const char* name, LLVMValueRef val, int isArg);
LLVMValueRef symbol_find(const char*,int *isArg);

#endif
