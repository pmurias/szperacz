package PostingsPtr;
use strict;
use warnings;
use Result;
use Dir::Self;
use Inline C=><<'C',PREFIX=>'postings_',TYPEMAPS=>'Typemap',INC=>"-I".__DIR__."/include";

#define debugf(args...) if (p->debug) printf(args)

#include "result.h"
#include "compress_list.h"
#include <stdlib.h>

typedef struct Postings {
    FILE* file;
    char* filename;
    int* offsets;
    int terms;
    int debug;
    int compressed;
} Postings;


Postings* create_compressed(char * filename) {
    Postings* p = malloc(sizeof(Postings));
    p->filename = filename;
    p->file = fopen(filename,"r");
    fread(&p->terms, sizeof(int), 1, p->file);
    p->offsets = calloc(p->terms, sizeof(int));
    p->debug = 1;
    p->compressed = 1;
    fread(p->offsets, sizeof(int), p->terms, p->file);
    return p;
}

Postings* create_uncompressed(char * filename) {
    Postings* p = (Postings *)malloc(sizeof(Postings));
    p->filename = filename;
    p->file = fopen(filename,"r");
    fread(&p->terms,sizeof(int),1,p->file);
    p->offsets = (int *)malloc(sizeof(int) * p->terms);
    p->debug = 1;
    p->compressed = 0;
    fread(p->offsets,sizeof(int),p->terms,p->file);
    return p;
}

Result* postings_empty(Postings* p) {
    Result* r = (Result*) malloc(sizeof(Result));
    int size = 0;
    int *buf = malloc(size * sizeof(int)); 
    r->buf = buf;
    r->size = size;
    return r;
}

/* 
    assume that file is set in a proper position 
    IMPORTANT call with len set to 0
*/
int parse_int_from_file(FILE * compressed_file, int * len) {
    unsigned char c;
    int pow = 1;
    int res = 0;
    do {
        fread(&c, sizeof(unsigned char), 1, compressed_file);
        ++(*len);
        if (c < 128) {
            res += c * pow;
        } else {
            res += (c - 128) * pow;
        }
        pow *= 128;    
    } while (c < 128);
    return res;    
}
/* assume that file is set in a proper position */
int * parse_chunk(FILE * compressed_file, int chunk_size, int compressed_chunk_size) {
    int i = 0;
    int * array = calloc(chunk_size, sizeof(int));
    int k = 0;
    int docID;
    int posSize;
    int prev = 0;
    int el;
    int len = 0;
    int j;
    int acc = 0;
    while (i < compressed_chunk_size) {
        docID = parse_int_from_file(compressed_file, &len);
        array[k++] = docID;
        i += len;
        len = 0;
        posSize = parse_int_from_file(compressed_file, &len);
        array[k++] = posSize;
        i += len;
        len = 0;
        for (j = 0; j < posSize; ++j) {
            el = parse_int_from_file(compressed_file, &len);
            i += len;
            len = 0;
            acc += el;
            array[k++] = acc;
        }
        acc = 0;
    }
    return array;
}

int get_chunk_size(FILE * compressed_file, int compressed_chunk_size) {
    int i = 0;
    int len = 0;
    int res = 0;
    int tmp;
    int file_pos = ftell(compressed_file);
    while (i < compressed_chunk_size) {
        tmp = parse_int_from_file(compressed_file, &len);
        ++res;
        i += len;
        len = 0;
    }
    fseek(compressed_file, file_pos, SEEK_SET);
    return res;
}

Result * compressed_postings_search(Postings * p, int tokID) {
    int offset = p->offsets[tokID];
    int end_offset;
    int size;
    if (tokID == p->terms-1) {
      int pos = ftell(p->file);
      fseek(p->file,0,SEEK_END);   
      end_offset = ftell(p->file);
      fseek(p->file, pos, SEEK_SET);
    } else {
      end_offset = p->offsets[tokID+1];
    }
    int compressed_chunk_size = (end_offset - offset) / sizeof(unsigned char);
    fseek(p->file,offset,SEEK_SET);
    size = get_chunk_size(p->file, compressed_chunk_size);
    int * buf = parse_chunk(p->file, size, compressed_chunk_size);
    Result* r = (Result*) malloc(sizeof(Result));
    r->buf = buf;
    r->size = size;
    return r;
}

Result* postings_search(Postings* p,int tokID) {
    if (p->compressed) return compressed_postings_search(p,tokID);
    if (tokID >= p->terms) { 
        printf("asking for a tokID %d > %d\n",tokID,p->terms);
        abort();
    }
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
sub create {
    my ($filename) = @_;
    if ($filename =~ /.compressed$/) {
        create_compressed($filename);        
    } else {
        create_uncompressed($filename);
    }
}
1;
## vim: expandtab sw=2 ft=c
