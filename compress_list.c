#include <math.h>
#include <stdlib.h>
#include <stdio.h>

/* compress integer and return result bytes */
unsigned char * compress_int(int n, int * steps) {
    if (n) {
        *steps = (int)(log2(n) / 7) + 1;
    } else {
        *steps = 1;
    }
    unsigned char * res = calloc(*steps, sizeof(unsigned char));
    int i;
    for (i = 0; i < *steps - 1; ++i) {
        res[i] = n % 128;
        n /= 128;
    }
    res[*steps - 1] = (n % 128) + 128;
    return res;
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
int * parse_chunk(FILE * compressed_file, int chunk_size) {
    int i = 0;
    int * array = calloc(chunk_size, sizeof(int));
    int k = 0;
    int docID;
    int posSize;
    int prev = 0;
    int el;
    int len = 0;
    int j;
    while (i < chunk_size) {
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
            array[k++] = el - prev;
            prev = el;
        }
        prev = 0;
        k += posSize;
    }
    return array;
}

int uncompress_int(unsigned char * comp) {
    unsigned char c;
    int pow = 1;
    int res = 0;
    int k = 0;
    do {
        c = comp[k];
        if (c < 128) {
            res += c * pow;
        } else {
            res += (c - 128) * pow;
        }
        pow *= 128;
        ++k;    
    } while (c < 128);
    return res;
}

int get_compressed_len(int * array, int chunk_size) {
    int i = 0;
    int j;
    int len;
    int docID;
    int posSize;
    int el;
    int prev = 0;
    int res = 0;
    unsigned char * tmp;
    while (i < chunk_size) {
        docID = array[i];
        tmp = compress_int(docID, &len);
        free(tmp);
        res += len;
        ++i;
        posSize = array[i];
        tmp = compress_int(posSize, &len);
        free(tmp);
        res += len;
        ++i;        
        for (j = 0; j < posSize; ++j) {
            el = array[i + j];
            tmp = compress_int(el - prev, &len);
            prev = el;
            free(tmp);
            res += len;
        }
        prev = 0;
        i += posSize;         
    }
    return res;
}

unsigned char * parse_array(int * array, int chunk_size, int compressed_chunk_size) {
    unsigned char * res = calloc(compressed_chunk_size, sizeof(unsigned char));
    int i = 0;
    int j, l;
    int len;
    int docID;
    int posSize;
    int el;
    int prev = 0;
    unsigned char * tmp;
    int k = 0;
    while (i < chunk_size) {
        docID = array[i];
        tmp = compress_int(docID, &len);
        for (j = 0; j < len; ++j) {
            res[k++] = tmp[j];
        }
        free(tmp);
        ++i;
        posSize = array[i];
        tmp = compress_int(posSize, &len);
        for (j = 0; j < len; ++j) {
            res[k++] = tmp[j];
        }
        free(tmp);
        ++i;        
        for (j = 0; j < posSize; ++j) {
            el = array[i + j];
            tmp = compress_int(el - prev, &len);
            for (l = 0; l < len; ++l) {
                res[k++] = tmp[l];
            }
            prev = el;
            free(tmp);
        }
        prev = 0;
        i += posSize;         
    }
    return res;
}


void compress_file(char * in_file_name, char * out_file_name) {
  FILE * in = fopen(in_file_name, "r");
  FILE * out = fopen(out_file_name, "w");
  FILE * tmp = fopen("index/tmp_file", "w");
  if (!out || !in) {
    perror("opening index:");
  }
  int terms;
  fread(&terms, sizeof(int), 1, in);
  int len;
  unsigned char * compressed_terms = compress_int(terms, &len);
  fwrite(compressed_terms, sizeof(unsigned char), len, out);
  int i;
  int offset;
  int next_offset;
  int written_to_tmp = 0;
  for (i = 0; i < terms; ++i) {
    fseek(in, (i + 1) * sizeof(int), SEEK_SET);
    fread(&offset, sizeof(int), 1, in);
    if (i == terms - 1) {
        fseek(in, 0, SEEK_END);
        next_offset = ftell(in);
    } else {
        fread(&next_offset, sizeof(int), 1, in);
    }
    int chunk_size = (next_offset - offset) / sizeof(int);
    int * array = calloc(chunk_size, sizeof(int));
    fseek(in, offset, SEEK_SET);
    fread(array, sizeof(int), chunk_size, in);
    int compressed_chunk_size = get_compressed_len(array, chunk_size);
    unsigned char * compressed_chunk = parse_array(array, chunk_size, compressed_chunk_size);
    fwrite(compress_int(compressed_chunk_size, &len), sizeof(unsigned char), len, out);
    fwrite(compressed_chunk, sizeof(unsigned char), compressed_chunk_size, tmp);
    written_to_tmp += compressed_chunk_size;
  }
  rewind(tmp);
  unsigned char c;
  for (i = 0; i < written_to_tmp; ++i) {
    fread(&c, sizeof(unsigned char), 1, tmp);
    fwrite(&c, sizeof(unsigned char), 1, out);
  }
  fclose(tmp);
  fclose(in);
  fclose(out);
}

int main() {
    compress_file("index/postings_at_once", "index/compressed_postings");
}
