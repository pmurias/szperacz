package ResultPtr;
use strict;
use warnings;
use Dir::Self;
use Inline C=><<'C',PREFIX=>'result_',TYPEMAPS=>'Typemap',INC=>"-I".__DIR__."/include";
#include "result.h"
#include <limits.h>
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
        return c;
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
        if (j < b->size) {
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

        if (j < b->size) {
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
void result_DESTROY(Result* a) {
    free(a->buf);
    free(a);
}
Result* result_or(Result* a,Result* b) {
    Result* c = (Result*) malloc(sizeof(Result));

    int size = a->size+b->size;//a->size > b->size ? b->size : a->size;
    c->buf = malloc(sizeof(int) * size);

    int i=0,j=0,h=0;

    int a_docID,b_docID,a_docSize,b_docSize;


    if (a->size != 0) {
        a_docID   = a->buf[i++]; 
        a_docSize = a->buf[i++];
    } else {
        a_docID = INT_MAX;
    }

    if (b->size != 0) {
        b_docID   = b->buf[j++]; 
        b_docSize = b->buf[j++];
    } else {
        b_docID = INT_MAX;
    }

    while (a_docID != INT_MAX || b_docID != INT_MAX) {

      if (a_docID == b_docID) {
        c->buf[h++] = a_docID;

        int where_to_write_size = h;
        where_to_write_size = h++;


        int a_to = i+a_docSize;
        int b_to = j+b_docSize;

        while (i < a_to || j < b_to) {
            if (i < a_to) {
                if (j < b_to) {
                    if (a->buf[i] < b->buf[j]) {
                        c->buf[h++] = a->buf[i++];
                    } else {
                        c->buf[h++] = b->buf[j++];
                    }
                } else {
                    c->buf[h++] = a->buf[i++];
                }
            } else {
                c->buf[h++] = b->buf[j++];
            }
        }

        c->buf[where_to_write_size] = h-where_to_write_size-1 ;

        if (i < a->size) {
            a_docID   = a->buf[i++]; 
            a_docSize = a->buf[i++];
        } else {
            a_docID = INT_MAX;
        }

        if (j < b->size) {
            b_docID   = b->buf[j++]; 
            b_docSize = b->buf[j++];
        } else {
            b_docID = INT_MAX;
        }


      } else if (a_docID < b_docID) {
        c->buf[h++] = a_docID;
        c->buf[h++] = a_docSize;

        int a_to = i+a_docSize;
        while (i < a_to) {
            c->buf[h++] = a->buf[i++];
        }

        if (i < a->size) {
            a_docID   = a->buf[i++]; 
            a_docSize = a->buf[i++];
        } else {
            a_docID = INT_MAX;
        }

      } else {

        c->buf[h++] = b_docID;
        c->buf[h++] = b_docSize;
        int b_to = j+b_docSize;
        while (j < b_to) {
//            printf("h=%d j=%d a->size=%d b->size=%d size=%d\n",h,j,a->size,b->size,size);
            c->buf[h++] = b->buf[j++];
        }

        if (j < b->size) {
            b_docID   = b->buf[j++]; 
            b_docSize = b->buf[j++];
        } else {
            b_docID = INT_MAX;
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
## vim: expandtab sw=2 ft=c
