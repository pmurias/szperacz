package PostingsPtr;
use strict;
use warnings;
use Result;
use Dir::Self;
use Inline C=><<'C',PREFIX=>'postings_',TYPEMAPS=>'Typemap',INC=>"-I".__DIR__."/include";

#define debugf(args...) if (p->debug) printf(args)

#include "result.h"

typedef struct Postings {
    FILE* file;
    char* filename;
    int* offsets;
    int terms;
    int debug;
} Postings;


Postings* postings_create(char* filename) {
    Postings* p = malloc(sizeof(Postings));
    p->filename = filename;
    p->file = fopen(filename,"r");
    fread(&p->terms,sizeof(int),1,p->file);
    p->offsets = (int) malloc(sizeof(int) * p->terms);
    p->debug = 1;
    fread((void*)p->offsets,sizeof(int),p->terms,p->file);
    return p;
}
Result* postings_search(Postings* p,int tokID) {
    int offset = p->offsets[tokID];
    int size;
    if (tokID == p->terms-1) {
      fseek(p->file,0,SEEK_END);   
      size = (ftell(p->file) - offset) / 4;
    } else {
      size =  (p->offsets[tokID+1] - offset) / 4;
    }
    fseek(p->file,offset,SEEK_SET);
    int *buf = malloc(size * sizeof(int)); 
    fread(buf,sizeof(int),size,p->file);

    Result* r = (Result*) malloc(sizeof(Result));
    r->buf = buf;
    r->size = size;
    return r;
}

Result* postings_phrase(Postings* p,Result* a,Result* b) {
    Result* c = (Result*) malloc(sizeof(Result));

    int size = a->size > b->size ? b->size : a->size;
    c->buf = malloc(sizeof(int) * size);

    int i=0,j=0,h=0;

    int a_docID,b_docID,a_docSize,b_docSize;


    a_docID   = a->buf[i++]; 
    a_docSize = a->buf[i++];
    b_docID   = b->buf[j++]; 
    b_docSize = b->buf[j++];

    while (i < a->size && j < b->size) {
      /*printf("i: %d j: %d a_docID: %d ? b_docID: %d\n",i,j,a_docID,b_docID);*/

      /* We don't include a document untill we know a phrase in it matches, but we only do it once. */
      int wrote_doc = 0;

      if (a_docID == b_docID) {

        /* We can only write the size once we know how many phrases match. */
        int where_to_write_size;
        int a_to = i+a_docSize, b_to = j+b_docSize;

        while (i < a_to && j < b_to) {
            if (a->buf[i]+1 == b->buf[j]) {
                if (!wrote_doc) {
                    c->buf[h++] = a_docID;
                    where_to_write_size = h++;
                    wrote_doc = 1;
                }
                c->buf[h++] = b->buf[j];
                i++;
                j++;
            } else if (a->buf[i] < b->buf[j]) {
                i++;
            } else {
                j++;
            }
        }

//        printf("document size %d\n",h-size+1);
        if (wrote_doc) {
          c->buf[where_to_write_size] = h-where_to_write_size-1 ;
        }

        i = a_to;j = b_to;
        a_docID   = a->buf[i++]; 
        a_docSize = a->buf[i++];
        b_docID   = b->buf[j++]; 
        b_docSize = b->buf[j++];
      } else if (a_docID < b_docID) {
        i += a_docSize;
        a_docID   = a->buf[i++]; 
        a_docSize = a->buf[i++];
      } else {
        j += b_docSize;
        b_docID   = b->buf[j++]; 
        b_docSize = b->buf[j++];
      }
    }
    c->size = h;
    return c;
}

C
sub lookup {
    my ($self,$tokID) = @_;
    $self->flatten($self->search($tokID));
}
1;
## vim: expandtab sw=2 ft=c
