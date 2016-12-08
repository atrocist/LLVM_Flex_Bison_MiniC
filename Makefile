LEVEL = ../..

vpath %.y $(SRC_DIR)
vpath %.lex $(SRC_DIR)

TOOLNAME=p2

SOURCES := main.c minic.y.c minic.lex.c Cmdline.c list.c symbol.c

LINK_COMPONENTS := bitreader bitwriter analysis 

include $(LEVEL)/Makefile.common

LIBS += -lfl

minic.y.c: minic.y
	bison -d -o $@ $^

minic.y.h: minic.y.c 

minic.lex.c: minic.lex minic.y.h
	flex -o$@ $^

list.c: list.h

Cmdline.c: cmdline.lex
	flex -PCmd -o$@ cmdline.lex 
