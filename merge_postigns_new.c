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

int get_len_of_postings(FILE ** file_descriptors, int no_files, int token_id, int * tokens_per_file) {
    int res = 0;
    int token_offset;
    int next_token_offset;
    int i;
    for (i = 0; i < no_files; ++i) {
        fseek(file_descriptors[i], (token_id + 1)* sizeof(int), SEEK_SET);
        fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
        if (token_id == tokens_per_file[i] - 1) {
            fseek(file_descriptors[i], 0, SEEK_END);
            next_token_offset = ftell(file_descriptors[i]);
        } else {
            fread(&next_token_offset, sizeof(int), 1, file_descriptors[i]);
        }
        res += (next_token_offset - token_offset) / sizeof(int);
    }
    return res;
}

void create_pos_structs(int * docs, int len_docs, pos ** res, int * no_pos) {
    int i = 0;
    *res = calloc(sizeof(pos), len_docs);
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
        (*res)[(*no_pos)++] = p;
    }
}

int find_number_of_docs(int * docs, int len_docs) {
    int i = 0;
    int res = 0;
    int docID;
    int posSize;    
    while (i < len_docs) {
        ++res;
        ++i;
        i += (docs[i] + 1); 
    }
    return res;
}


void read_docs(FILE * file_desc, int chunk_size, int * chunk) {
    fread(chunk, sizeof(int), chunk_size / sizeof(int), file_desc);
}

void find_docs_for_token(FILE ** file_descriptors, int no_files, 
                         int token_processed, int * tokens_per_file, pos ** pos_list, int * no_pos) {
    int token_offset;
    int next_token_offset;
    int len_of_postings = get_len_of_postings(file_descriptors, no_files, token_processed, tokens_per_file);
    //printf("len_of_postings = %d\n", len_of_postings);
    int * array = calloc(len_of_postings, sizeof(int));
    int * current = array;
    int number_of_docs = 0;
    int i;
    for (i = 0; i < no_files; ++i) {
        if (token_processed < tokens_per_file[i]) {
            fseek(file_descriptors[i], (token_processed + 1) * sizeof(int), SEEK_SET);
            fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
            if (token_processed == tokens_per_file[i] - 1) {
                fseek(file_descriptors[i], 0, SEEK_END);
                next_token_offset = ftell(file_descriptors[i]);
            } else {
                fread(&next_token_offset, sizeof(int), 1, file_descriptors[i]);
            }
            printf("token offset = %d\n", token_offset);
            printf("next_token_offset = %d\n", next_token_offset);
            fseek(file_descriptors[i], token_offset, SEEK_SET);
            read_docs(file_descriptors[i], next_token_offset - token_offset, current);
            number_of_docs += find_number_of_docs(current, (next_token_offset - token_offset) / sizeof(int));
            printf("number_of_docs = %d\n", number_of_docs);
            printf("po find_number_of_docs\n");
            current += (next_token_offset - token_offset) / sizeof(int);
        }
    }
        
    printf("Ha\n");
    create_pos_structs(array, number_of_docs, pos_list, no_pos);
    free(array);
    printf("Bam\n");
    printf("Blah = %d\n", (*pos_list)[0].docID);
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
    printf("OVERALL TOKENS = %d\n", overall_tokens);
    fwrite(&overall_tokens, sizeof(int), 1, out);
    /* Make space for offsets */
    int dummy = 0;
    for (i = 0; i < overall_tokens; ++i) {
        fwrite(&dummy, sizeof(int), 1, out);
    }
    int token_processed;
    FILE * file_offsets = out;
    fseek(file_offsets, sizeof(int), SEEK_SET);
    int file_pos = ftell(out);
    fwrite(&file_pos, sizeof(int), 1, file_offsets);
    for (token_processed = 0; token_processed < overall_tokens; ++token_processed) {
        printf("token %d\n", token_processed);
        pos *pos_list;
        int no_pos = 0;
        find_docs_for_token(file_descriptors, no_files, token_processed, tokens_per_file,
                            &pos_list, &no_pos);
        printf("1\n");
        printf("pos_list[0].docID = %d\n", pos_list[0].docID);
        sort_pos_list(pos_list, no_pos);
        printf("2\n");
        int doc;
        for (doc = 0; doc < no_pos; ++doc) {
            printf("3\n");
            printf("pos_list[doc].docID = %d\n", pos_list[doc].docID);
            fwrite(&(pos_list[doc].docID), sizeof(int), 1, out);
            printf("4\n");
            fwrite(&(pos_list[doc].posSize), sizeof(int), 1, out);
            printf("5\n");
            int k;
            for (k = 0; k < pos_list[doc].posSize; ++k) {
                fwrite(&(pos_list[doc].pos[k]), sizeof(int), 1, out);
            }
            free(pos_list[doc].pos);
            printf("6\n");
        }
        free(pos_list);
        file_pos = ftell(out); 
        fwrite(&file_pos, sizeof(int), 1, file_offsets);  
    }
}

int main() {
    create_merged_file(24, "index/postings_full");
    return 0;
}
