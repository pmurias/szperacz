#include <math.h>

/* compress integer and return result bytes */
int compress_int(int n, unsigned char * res) {
    int steps = (int)(log(n) / 7);
    res = calloc(steps, sizeof(unsigned char));
    int i;
    for (i = 0; i < steps - 1; ++i) {
        res[i] = n % 128;
        n /= 128;
    }
    res[steps - 1] = (n % 128) + 128;
    return steps * sizeof(unsigned char);
}

void compress_file(FILE * in) {
  FILE * out = fopen(file_name, "w");
  if (!out) {
    perror("opening index:");
  }
  int terms;
  fread(&terms, sizeof(int), 1, in);
  fwrite(&terms, sizeof(int), 1, out);
  int i;
  int dummy = 0;
  for (i = 0; i < terms; ++i) {
    fwrite(&dummy, sizeof(int), terms, out);      
  }
  int * offsets = calloc(terms, sizeof(int)); 
  int offset = 0;
  int docID;
  int list_len;
  int j;
  for (i = 0; i < terms; ++i) {
    fread(&offset, sizeof(int), 1, in);
    if (offset) {
        int next = 0;
        do {
            fread(&next, sizeof(int), 1, in);
        } while (!next);
        /* FIXME This will not work for file ending */
        int diff = next - offset;
        int bytes = 0;
        fseek(in, offset, SEEK_SET);
        while (bytes < diff) {
            fread(&docID, sizeof(int), 1, in);
            bytes += sizeof(int);
            fread(&list_len, sizeof(int), 1, in);
            bytes += sizeof(int);
            fwrite(&docID, sizeof(int), 1, out);
            fwrite(&list_len, sizeof(int), 1, out);
            unsigned char * compressed;
            int n;
            fread(&n, sizeof(int), 1, in);
            bytes += sizeof(int);
            int len_compressed = compress_int(n, compressed);
            int total_bytes = len_compressed;
            fwrite(compressed, sizeof(unsigned char), len_compressed, out);
            int p = n;
            for (j = 0; j < list_len; ++j) {
                fread(&n, sizeof(int), 1, in);
                bytes += sizeof(int);
                int d = n - p; 
                len_compressed = compress_int(d, compressed);
                fwrite(compressed, sizeof(unsigned char), len_compressed, out);
                total_bytes += len_compressed;
                p = n;
            }
        }
        offsets[i] = total_bytes;        
    } else {
        offsets[i] = 0;
    }
    fseek(in, i + 1, SEEK_SET);
  }
  fseek(out, 1, SEEK_SET);
  for (i = 0; i < terms; ++i) {
    fwrite(&offsets[i], sizeof(int), out);
  }
}
