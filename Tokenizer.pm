package TokenizerPtr;
use strict;
use warnings;
use Inline C=><<'C',PREFIX=>'tokenizer_',TYPEMAPS=>'Typemap';
typedef struct occurence {
  int tokID;
  int docID;
  int pos;
} occurence;

typedef struct Tokenizer {
  occurence *buf;
  int size;
  int bufTop;
} Tokenizer;

/* Creates a tokenizer with space for size tokens */
Tokenizer* tokenizer_create(int size) {
    Tokenizer* t = malloc(sizeof(Tokenizer));
    t->size = size;
    t->buf = malloc(sizeof(occurence) * size);
    t->bufTop = 0;
    return t;
}


int tokenizer_bufTop(Tokenizer* t) {
    return t->bufTop;
}


/* adds a token to the buffer */
void tokenizer_add(Tokenizer* t,int tokID,int docID,int pos) {
    if (t->bufTop >= t->size) {
        printf("no space in buffer\n");
        return;
    }
    t->buf[t->bufTop].tokID = tokID;
    t->buf[t->bufTop].docID = docID;
    t->buf[t->bufTop].pos = pos;
    t->bufTop++;
}


/* debugging method that prints out the buffer */
void tokenizer_print(Tokenizer* t) {
    int i=0;
    for (i=0;i < t->bufTop;i++) {
        printf("%d,%d,%d\n",t->buf[i].tokID,t->buf[i].docID,t->buf[i].pos);
    }
}
static int occurence_cmp(const void* va,const void *vb) {
  occurence* a = (occurence*) va;
  occurence* b = (occurence*) vb;
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
  qsort(t->buf,t->bufTop,sizeof(occurence),occurence_cmp);
}

void tokenizer_DESTROY(Tokenizer* t) {
   free(t->buf); 
   free(t); 
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
  while (i < t->bufTop) {
    if (t->buf[i].tokID != current_tokID) {
      current_tokID = t->buf[i].tokID; 
      if (current_tokID >= terms) {
        terms = current_tokID+1;
      }
    }
    i++;
  }


  wrt(terms);
  /* Making space for the offsets */
  int* offsets = calloc(terms,sizeof(int));
  fwrite(offsets,sizeof(int),terms,out);
        

  i = 0;
  int offset = sizeof(int) * (terms + 1);

  while (i < t->bufTop) {
    int start = i;
    int current_tokID = t->buf[i].tokID; 
    int current_docID = -1;

    offsets[current_tokID] = offset;
    while (t->buf[i].tokID == current_tokID) {
      int docID = t->buf[i].docID;
      int doc_size = 0;
      offset += sizeof(int);
      wrt(docID);

      // We write the number of the occurences of the token in the doc before we write the occurences.

      int j = i;
      while (t->buf[j].tokID == current_tokID && t->buf[j].docID == docID) {
        doc_size++;
        j++;
      }
      offset += sizeof(int);
      wrt(doc_size);

      while (t->buf[i].tokID == current_tokID && t->buf[i].docID == docID) {
        offset += sizeof(int);
        wrt(t->buf[i].pos);
        i++;
      }
    }

      
  }

  // offsets[token] is 0 for tokens which are not in the buffer, we must fix that.
  {
    int i;
    int offset; // The token with the greatest tokID is always in the buffer.
    for (i=terms-1;i>=0;i--) {
      if (offsets[i] == 0) offsets[i] = offset;
      else offset = offsets[i]; 
    }
  }

  fseek(out,sizeof(int),SEEK_SET);
  fwrite(offsets,sizeof(int),terms,out);

  free(offsets);

  fclose(out);
  
}
C
1;
## vim: expandtab sw=2 ft=c
