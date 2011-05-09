#include <limits.h>

typedef struct min_res {
    int min_val;
    int min_ind;
} min_res;

typedef struct file_pos {
    FILE * file_part;
    int list_pos; /* next position to be read in list */
    int list_size;
} file_pos;

min_res * find_min(int * first_elements) {
    int i;
    min_res * mr = malloc(sizeof(min_res));
    mr->min_val = INT_MAX;
    for (i = 0; i < sizeof(first_elements) / sizeof(int); ++i) {
        if (first_elements[i] <= mr->min_val) {
            mr->min_val = first_elements[i];
            mr->min_ind = i;
        } 
    }
    return min_res;
}

/* returns 1 if end of posting list reached 0 otherwise */
int update_first_elements_list(int file_ind, int * first_elements, file_pos * files_info,
                               int * moved, int * files_original_ids) {
    if (files_info[file_ind].list_pos == files_info[file_ind].list_size) {
        /* list end reached */
        first_elements[file_ind] = INT_MAX;
        return 1;        
    }
    fread(first_elements[file_ind], sizeof(int), 1, files_info[file_ind].file_part);
    moved[files_original_ids[file_ind]] += sizeof(int);
    ++files_info[file_ind].list_pos;
    return 0;
}

/* Assume that file_descriptors are at position right before PostingList Size */
file_pos * create_file_pos_list(int no_files, FILE ** file_descriptors, 
                                int * result_posting_list_length) {
    file_pos * file_pos_list = calloc(no_files, sizeof(file_pos));
    int i;
    for (i = 0; i < no_files; ++i) {
        fread(&file_pos_list[i].list_size, sizeof(int), 1, file_descriptors[i]);
        *result_posting_list_length += file_pos_list[i].list_size;
        file_pos_list[i].file_part = file_descriptors[i];
        file_pos_list[i].list_pos = 0;
    }
    return file_pos_list;
}

/* Assumes that out is at next free position */
void merge_postings(file_pos * files_info, int no_files, FILE * out,
                    int * moved, int * files_original_ids) {
    int finished_lists = 0;
    int i;
    int * first_elements = calloc(no_files, sizeof(int));
    for (i = 0; i < no_files; ++i) {
        finished_lists += update_first_elements_list(i, first_elements, files_info, 
                                                     moved, files_original_ids);
    }
    while (finished_lists < no_files) {
        min_res * mr = find_min(first_elements);
        fwrite(&mr->min_val, sizeof(int), 1, out);
        update_first_elements_list(mr->min_ind, first_elements, files_info,
                                   moved, files_original_ids);
    }
}

/* Assume that file_descriptors are before PostingList size field */
int create_posting_for_doc(FILE ** files_with_doc, int * moved, int no_files_with_doc, 
                            int * files_original_ids, int docID, FILE * out) {
    fwrite(&docID, sizeof(int), 1, out);
    int res_postinglist_length = 0;
    int i;
    file_pos * files_info = create_file_pos_list(no_files_with_doc, files_with_doc, 
                                                 &res_postinglist_length);
    for (i = 0; i < no_files_with_doc; ++i) {
        moved[files_original_ids[i]] += sizeof(int);
    }
    fwrite(res_postinglist_length, sizeof(int), 1, out);
    merge_postings(files_info, no_files_with_doc, out, moved, files_original_ids);
    return res_postinglist_length + 2 * sizeof(int);         
}

void get_files_with_token(FILE ** file_descriptors, int no_files, int token_id, 
                          int * res_len, FILE ** res_files, int * block_lengths) {
    int i;
    int token_offset;
    for (i = 0; i < no_files; ++i) {
        fseek(file_descriptors[i], token_id, SEEK_SET); 
        fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
        if (token_offset > 0) {
            ++(*res_len);
        }
    }
    res_files = calloc(*res_len, sizeof(FILE *));
    block_lengths = calloc(*res_len, sizeof(int));
    int k = 0;
    for (i = 0; i < no_files; ++i) {
        fseek(file_descriptors[i], token_id, SEEK_SET);
        fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
        if (token_offset > 0) {
            /* docs with given token found */
            int begining = token_offset;
            fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
            while (!token_offset) {
                fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
            }
            res_files[k] = file_descriptors[i];
            block_lengths[k] = token_offset - begining;
            fseek(file_descriptors[i], token_id, SEEK_SET);
            fread(&token_offset, sizeof(int), 1, file_descriptors[i]);
            fseek(res_files[k], token_offset, SEEK_SET);
        } 
    }    
}

void find_next_doc_for_token(FILE ** files_with_token, int no_files, int * block_lengths,
                             int * moved, FILE ** files_with_doc, int * no_files_with_doc,
                             int * files_original_ids, int * doc_to_create) {
    int i;
    int min_doc_ID = INT_MAX;
    int docID;
    for (i = 0; i < no_files; ++i) {
        if (moved[i] < block_lenghts[i]) {
            fread(&docID, sizeof(int), 1, files_with_token[i]);
            if (docID < min_doc_ID) {
                min_docID = docID;
            }
            fseek(files_with_token[i], -sizeof(int), SEEK_CUR);
        }
    }
    for (i = 0; i < no_files; ++i) {
        if (moved[i] < block_lenghts[i]) {
            fread(&docID, sizeof(int), 1, files_with_token[i]);
            if (docID == min_doc_ID) {
                ++(*no_files_with_doc);
            } 
            fseek(files_with_token[i], -sizeof(int), SEEK_CUR);
        }
    }
    files_with_doc = calloc(*(no_files_with_doc), sizeof(FILE *));
    files_original_ids = calloc(*(no_files_with_doc), sizeof(int));
    int k = 0;
    for (i = 0; i < no_files; ++i) {
        if (moved[i] < block_lenghts[i]) {
            fread(&docID, sizeof(int), 1, files_with_token[i]);
            if (docID == min_doc_ID) {
                files_with_doc[k] = files_with_token[i];
                files_original_ids[k] = i;
                moved[i] += sizeof(int);    
            } else {
                fseek(files_with_token[i], -sizeof(int), SEEK_CUR);
            }
        }
    }
    *doc_to_create = min_doc_ID;    
}

/* Assume that all file parts have ALL terms */
/* needs open FILES as arguments */
void create_resulting_file(FILE ** file_descriptors, int no_files, char * file_name) {
  FILE * out = fopen(file_name, "w");
  if (!out) {
    perror("opening index:");
  }
  int terms;
  fread(&terms, sizeof(int), 1, file_descriptors[0]);
  rewind(file_descriptors[0]);
  fwrite(&terms, sizeof(int), 1, out);
  int * offsets = calloc(terms, sizeof(int));
  int i;
  int dummy = 0;
  fwrite(dummy, sizeof(int), terms, out);
  for (i = 0; i < terms; ++i) {
    int res_len = 0;
    FILE ** res_files;
    int * block_lenghts;
    get_files_with_token(file_descriptors, no_files, i, &res_len, res_files, block_lenghts);
    int * moved = calloc(res_len, sizeof(int));
    FILE ** files_with_doc;
    int no_files_with_doc = 0;
    int doc_to_create;
    int * files_original_ids;
    do {
        find_next_doc_for_token(res_files, res_len, block_lengths, moved, files_with_doc,
                                &no_files_with_doc, files_original_ids, &doc_to_create);
        if (no_files_with_doc) {
            offsets[i] += create_posting_for_doc(files_with_doc, moved, no_files_with_doc, files_original_ids,
                                                doc_to_create, out);
        }
    } while (no_files_with_doc);
  }
  fseek(out, sizeof(int) * (terms + 1), SEEK_SET);
  int prev = sizeof(int) * (terms + 1);
  for (i = 0; i < terms; ++i) {
    int sum = offsets[i] + prev;
    fwrite(&sum, sizeof(int), 1, out);
    prev = sum;
  }
}

