package TokenizerPtr;
use strict;
use warnings;
#use Inline qw(Force Noisy Info);
use Inline C=><<'C',PREFIX=>'tokenizer_',TYPEMAPS=>'Typemap';
typedef struct pos{
  int tokID;
  int docID;
  int pos;
} pos;
typedef struct Tokenizer {
  pos *buf;
  int docID;
  int pos;
  int size;
  int i;
} Tokenizer;

/* Creates a tokenizer with space for size tokens */
Tokenizer* tokenizer_create(int size) {
    Tokenizer* t = malloc(sizeof(Tokenizer));
    t->pos = 0;
    t->docID = 0;
    t->size = size;
    t->buf = malloc(sizeof(pos) * size);
    t->i = 0;
    return t;
}

/* adds a token to the buffer, requires a previous call to set_docID */
void tokenizer_add(Tokenizer* t,int tokID) {
    if (t->i >= t->size) {
        printf("no space in buffer\n");
        return;
    }
    t->buf[t->i].tokID = tokID;
    t->buf[t->i].pos = t->pos;
    t->buf[t->i].docID = t->docID;
    t->pos++;
    t->i++;
}
/* sets the docID for the subsequent ->add calls */
void tokenizer_set_docID(Tokenizer* t,int docID) {
    t->docID = docID;
}

/* debugging method that prints out the buffer */
void tokenizer_print(Tokenizer* t) {
    int i=0;
    for (i=0;i < t->i;i++) {
        printf("%d,%d,%d\n",t->buf[i].tokID,t->buf[i].docID,t->buf[i].pos);
    }
}
static int pos_cmp(const void* va,const void *vb) {
  pos* a = (pos*) va;
  pos* b = (pos*) vb;
  /*printf("(%d,%d,%d) ? (%d,%d,%d)\n",a->tokID,a->docID,a->pos,b->tokID,b->docID,b->pos);*/
  int tmp;
  tmp = a->tokID - b->tokID;
  if (tmp) return tmp;
  tmp = a->docID - b->docID;
  if (tmp) return tmp;
  return a->pos - b->pos;
}

/* sorts the tokens into a correct order */
void tokenizer_sort(Tokenizer* t) {
  qsort(t->buf,t->i,sizeof(pos),pos_cmp);
}

/* writes out the tokens to a file */
#define wrt(X) fwrite(&X,1,sizeof(int),out);
void tokenizer_write(Tokenizer* t,char *to) {
  FILE* out = fopen(to,"w");
  if (!out) {
    perror("opening index:");
  }

  int per_tok = 0;
  int tok_start = 0;

  int current_docID = -1;

  int i = 0;

  int terms = 0;
  int current_tokID = -1;
  while (i < t->i) {
    if (t->buf[i].tokID != current_tokID) {
      current_tokID = t->buf[i].tokID; 
      if (current_tokID >= terms) {
        terms = current_tokID+1;
      }
    }
    i++;
  }

  //printf("### writing out %d\n",terms);

  wrt(terms);
  int* offsets = calloc(terms,sizeof(int));
  fwrite(offsets,sizeof(int),terms,out);
        

  /*int tok_size = 1;
  while (i < t->i) {
    int start = i;
    int current_tokID = t->buf[i].tokID; 
    int current_docID = -1;

    while (t->buf[i].tokID == current_tokID) {
      if (t->buf[i].docID == current_docID) {
        tok_size += 2;
      }
      tok_size++;
      i++;
    }
  }
  wrt(tok_size);*/
    
  i = 0;
  int offset = sizeof(int) * (terms + 1);

  while (i < t->i) {
    int start = i;
    int current_tokID = t->buf[i].tokID; 
    int current_docID = -1;
    //printf("offset for %d = %d\n",current_tokID,offset);
    offsets[current_tokID] = offset;
    while (t->buf[i].tokID == current_tokID) {
      int docID = t->buf[i].docID;
      int doc_size = 0;
      offset += sizeof(int);
      //printf("docID = %d\n",docID);
      wrt(docID);
      int j = i;
      while (t->buf[j].tokID == current_tokID && t->buf[j].docID == docID) {
        doc_size++;
        j++;
      }
      offset += sizeof(int);
      //printf("doc_size = %d\n",doc_size);
      wrt(doc_size);
      while (t->buf[i].tokID == current_tokID && t->buf[i].docID == docID) {
        offset += sizeof(int);
        wrt(t->buf[i].tokID);
        i++;
      }
    }

      
  }

  // offsets[token] is 0 for tokens which are not in the buffer, we must fix that
  {
    int i;
    int offset; // the token with the greatest tokID is always in the buffer
    for (i=terms-1;i>=0;i--) {
      if (offsets[i] == 0) offsets[i] = offset;
      else offset = offsets[i]; 
    }
  }

  fseek(out,sizeof(int),SEEK_SET);
  fwrite(offsets,sizeof(int),terms,out);

  free(offsets);

  /*
  for (i = 0;i < t->i;i++) {
    wrt();
  }

  i = 0;
  while (i < t->i) {
    int start = i;
    int current_tokID = t->buf[i].tokID; 
    int current_docID = -1;

    while (t->buf[i].tokID == current_tokID) {
    }
    printf("%d = %d\n",current_tokID,tok_size);
  }
  */
  fclose(out);
  
}
C
1;
## vim: expandtab sw=2 ft=c