package PostingsPtr;
use strict;
use warnings;
use Inline ; #qw(Force Noisy Info);
use Inline C=><<'C',PREFIX=>'postings_',TYPEMAPS=>'Typemap';

typedef struct Postings {
    FILE* file;
    char* filename;
    int* offsets;
    int terms;
} Postings;

typedef struct Result {
    int size;
    int* buf;
} Result;

Postings* postings_create(char* filename) {
    Postings* p = malloc(sizeof(Postings));
    p->filename = filename;
    //printf("opening filename %s\n",filename);
    p->file = fopen(filename,"r");
    //printf("pos = %d\n",ftell(p->file));
    fread(&p->terms,sizeof(int),1,p->file);
    //printf("terms %d\n",p->terms);
    //printf("pos = %d\n",ftell(p->file));
    p->offsets = (int) malloc(sizeof(int) * p->terms);
    fread((void*)p->offsets,sizeof(int),p->terms,p->file);
    /*
    int i;
    for (i=0;i<p->terms;i++) {
        printf("offset i = %d\n",p->offsets[i]);
    }
    */
    return p;
}
Result* postings_search(Postings* p,int tokID) {
    //printf("searching for token: %d\n",tokID);
    int offset = p->offsets[tokID];
    int size;
    if (tokID == p->terms-1) {
      fseek(p->file,0,SEEK_END);   
      size = (ftell(p->file) - offset) / 4;
    } else {
      //printf("next offset %d\n",p->offsets[tokID+1]);
      size =  (p->offsets[tokID+1] - offset) / 4;
    }
    fseek(p->file,offset,SEEK_SET);
    //printf("offset = %d next_offset = %d\n",p->offsets[tokID],p->offsets[tokID+1]);
    //printf("reading chunk of data of size: %d\n",size);
    int *buf = malloc(size * sizeof(int)); 
    fread(buf,sizeof(int),size,p->file);

    Result* r = (Result*) malloc(sizeof(Result));
    r->buf = buf;
    r->size = size;
    return r;
}
Result* postings_phrase(Postings* p,Result* a,Result* b) {
    Result* c = (Result*) malloc(sizeof(Result));
    if (!a->size || !b->size) {
      c->size = 0;
      c->buf = malloc(0);
    } else {
      int size = a->size > b->size ? a->size : b->size;
      c->buf = malloc(sizeof(int) * size);
    }
    int i=0,j=0,h=0;

    int a_docID,b_docID,a_docSize,b_docSize;


    a_docID   = a->buf[i++]; 
    a_docSize = a->buf[i++];
    b_docID   = b->buf[j++]; 
    b_docSize = b->buf[j++];

    while (i < a->size && j < b->size) {
      /*printf("i: %d j: %d a_docID: %d ? b_docID: %d\n",i,j,a_docID,b_docID);*/
      if (a_docID == b_docID) {
        c->buf[h++] = a_docID;
        int size = h++;
        int a_to = i+a_docSize, b_to = j+b_docSize;
        while (i < a_to && j < b_to) {
            if (a->buf[i]+1 == b->buf[j]) {
                printf("found %d!\n",a_docID);
                c->buf[h++] = b->buf[j];
                i++;
                j++;
            } else if (a->buf[i] < b->buf[j]) {
                i++;
            } else {
                j++;
            }
        }
        printf("document size %d\n",h-size+1);
        c->buf[size] = h-size-1 ;

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
    for (i=0;i<c->size;i++) {
        printf("%d\n",c->buf[i]);
    }
    return c;
}

void postings_flatten(Postings* p,Result * r) {
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
C
sub lookup {
    my ($self,$tokID) = @_;
    $self->flatten($self->search($tokID));
}
1;
## vim: expandtab sw=2 ft=c
