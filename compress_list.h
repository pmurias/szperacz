#ifndef __compress_list_H
#define __compress_list_H

int * parse_chunk(FILE * compressed_file, int chunk_size);

int parse_int_from_file(FILE * compressed_file, int * len);

int get_chunk_size(FILE * compressed_file, int compressed_chunk_size);

#endif
