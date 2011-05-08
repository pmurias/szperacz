package ResultPtr;
use strict;
use warnings;
use Dir::Self;
use Inline C=><<'C',PREFIX=>'result_',TYPEMAPS=>'Typemap',INC=>"-I".__DIR__."/include";
#include "result.h"
void result_flatten(Result * r) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    int i = 0;
    while (i < r->size) {
        int docID = r->buf[i++]; 
        int docSize = r->buf[i++];
        Inline_Stack_Push(newSViv(docID));
        i += docSize;
    }
    Inline_Stack_Done;
}
void result_all(Result * r) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    int i = 0;
    while (i < r->size) {
        Inline_Stack_Push(newSViv(r->buf[i++]));
    }
    Inline_Stack_Done;
}
Result* result_and(Result* a,Result* b) {
    Result* c = (Result*) malloc(sizeof(Result));

    int size = a->size > b->size ? b->size : a->size;
    c->buf = malloc(sizeof(int) * size);

    int i=0,j=0,h=0;

    int a_docID,b_docID,a_docSize,b_docSize;


    if (!a->size || !b->size) {
        c->size = 0;
        return;
    }

    a_docID   = a->buf[i++]; 
    a_docSize = a->buf[i++];
    b_docID   = b->buf[j++]; 
    b_docSize = b->buf[j++];

    while (1) {

      if (a_docID == b_docID) {
        c->buf[h++] = a_docID;
        c->buf[h++] = 0;

        i += a_docSize;
        if (i < a->size) {
            a_docID   = a->buf[i++]; 
            a_docSize = a->buf[i++];
        } else {
            break;
        }

        j += b_docSize;
        if (i < b->size) {
            b_docID   = b->buf[j++]; 
            b_docSize = b->buf[j++];
        } else {
            break;
        }

      } else if (a_docID < b_docID) {
        i += a_docSize;
        if (i < a->size) {
            a_docID   = a->buf[i++]; 
            a_docSize = a->buf[i++];
        } else {
            break;
        }

      } else {
        j += b_docSize;

        if (i < b->size) {
            b_docID   = b->buf[j++]; 
            b_docSize = b->buf[j++];
        } else {
            break;
        }

      }
    }

    c->size = h;
    return c;

}
C
sub array {
    my ($self,) = @_;
    [$self->flatten];
}
1;
