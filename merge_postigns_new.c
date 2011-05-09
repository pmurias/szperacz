#include <limits.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct pos {
    int docID;
    int posSize;
    int * pos;
} pos;

int get_number_of_tokens(FILE ** file_descriptors, int no_files, int * tokens_per_file) {
    int max = INT_MIN;
    int i;
    int tokens;
    for (i = 0; i < no_files; ++i) {
        fread(&tokens, sizeof(int), 1, file_descriptors[i]);
        tokens_per_file[i] = tokens;
        if (max <= tokens) {
            max = tokens;
        }
        rewind(file_descriptors[i]);
    }
    return max;
}

void read_docs(FILE * file_desc, int chunk_size, int * chunk) {
    fread(chunk, sizeof(int), chunk_size / sizeof(int), file_desc);
}

int get_length_of_postings(FILE ** file_descriptors, int no_files, int token_id) {
    int res = 0;
    int token_offset;
    int next_token_offset;
    fseek(file_descriptors[i], token_id * sizeof(int), SEEK_SET);
    fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
    fread(&next_token_offset, sizeof(int), 1, file_descriptors[i]);
    res += (next_token_offset - token_offset) / sizeof(int);
    return res;
}

void create_pos_structs(int * docs, int len_docs, pos * res, int * no_pos) {
    i = 0;
    res = calloc(sizeof(pos), len_docs);
    while (i < len_docs) {
        pos p;
        p.docID = docs[i++];
        p.posSize = docs[i++];
        p.pos = calloc(p.posSize, sizeof(int));
        int j;
        for (j = 0; j < p.posSize; ++j) {
            p.pos[j] = docs[i + j];
        }
        i += p.posSize;
        res[(*no_pos)++] = p;
    }
    
}

int find_number_of_docs(int * docs, int len_docs) {
    int i = 0;
    int res = 0;
    int docID;
    int posSize;
    while (i < len_docs) {
        ++res;
        i += docs[++i]; 
    }
    return res;
}

void find_docs_for_token(FILE ** file_descriptors, int no_files, 
                         int token_processed, int * tokens_per_file, pos * pos_list, int * no_pos) {
    int token_offset;
    int next_token_offset;
    int len_of_postings = get_len_of_postings(file_descriptors, no_files, token_processed);
    array = calloc(len_of_postings, sizeof(int));
    int * current = array;
    int number_of_docs = 0;
    for (i = 0; i < no_files; ++i) {
        if (token_processed <= tokens_per_file) {
            fseek(file_descriptors[i], token_processed * sizeof(int), SEEK_SET);
            fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
            fread(&next_token_offset, sizeof(int), 1, file_descriptors[i]);
            read_docs(file_descriptors[i], next_token_offset - token_offset, current);
            number_of_docs += find_number_of_docs(current, (next_token_offset - token_offset) / sizeof(int));
            current += (next_token_offset - token_offset) / sizeof(int);
        }
    }    
    create_pos_structs(array, number_of_docs, pos_list, &no_pos);
}

static int pos_cmp(const void * va, const void * vb) {
    pos * a = (pos *)va;
    pos * b = (pos *)vb;
    return (a->docID - b->docID);
}

void sort_pos_list(pos * poslist, int no_pos) {
    qsort(poslist, no_pos, sizeof(pos), pos_cmp);
}

void create_merged_file(int no_files, char * output_name) {
    int i;
    FILE ** file_descriptors = calloc(no_files, sizeof(FILE *));
    for (i = 0; i < no_files; ++i) {
        char num[3];
        sprintf(num, "%d", i);
        char file_name[] = "index/postings";
        strcat(file_name, num);
        file_descriptors[i] = fopen(file_name, "r");
        if (!file_descriptors[i]) {
            perror("opening partial index:\n");
        }
    }
    FILE * out = fopen(output_name, "w");
    int * tokens_per_file = calloc(no_files, sizeof(int));
    int overall_tokens = get_number_of_tokens(file_descriptors, no_files, tokens_per_file);
    fwrite(&overall_tokens, sizeof(int), 1, out);
    /* Make space for offsets */
    int dummy = 0;
    for (i = 0; i < overall_tokens; ++i) {
        fwrite(&dummy, sizeof(int), 1, out);
    }
    int token_processed;
    FILE * file_offsets = out;
    fseek(file_offsets, sizeof(int), SEEK_SET);
    fwrite(&ftell(out), sizeof(int), 1, file_offsets);
    for (token_processed = 0; token_processed < overall_tokens; ++token_processed) {
        pos * pos_list;
        int no_pos = 0;
        find_docs_for_token(file_descriptors, no_files, token_processed, tokens_per_file,
                            pos_list, &no_pos);
        sort_pos_list(pos_list, no_pos);
        int doc;
        for (doc = 0; doc < no_pos; ++doc) {
            fwrite(&pos_list[doc].docID, sizeof(int), 1, out);
            fwrite(&pos_list[doc].posSize, sizeof(int), 1, out);
            int k;
            for (k = 0; k < pos_list[doc].posSize; ++k) {
                fwrite(&pos_list[doc].pos[k], sizeof(int), 1, out);
            }
        }
        fwrite(&ftell(out), sizeof(int), 1, file_offsets);  
    }
}

int main() {
    create_merged_file(24, "postings_full");
    return 0;
}
