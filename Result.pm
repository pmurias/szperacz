package ResultPtr;
use strict;
use warnings;
use Dir::Self;
use Inline C=><<'C',PREFIX=>'result_',TYPEMAPS=>'Typemap',INC=>__DIR__."/include";
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
C
sub array {
    my ($self,) = @_;
    [$self->flatten];
}
1;
