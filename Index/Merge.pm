package Index::Merge;
use strict;
use warnings;
use Inline C=><<'C';
typedef struct file {
    FILE *f;
    int terms;
    int *offsets;
} file;

int chunk_size(file f,int tokID)
{
    int offset = f.offsets[tokID];
    if (tokID == f.terms - 1) {
	fseek(f.f, 0, SEEK_END);
	return (ftell(f.f) - offset) / 4;
    } else {
	return (f.offsets[tokID + 1] - offset) / 4;
    }
}

void merge_index(char* input_files,char* output_file,int parts)
{
    int i;

    file out;

    out.f = fopen(output_file, "w");
    out.terms = 0;



    file *input = malloc(sizeof(file) * parts);


    char filename[100];
    for (i = 0; i < parts; i++) {
	sprintf(filename, input_files, i);
        printf("%s\n",filename);
	input[i].f = fopen(filename, "r");
	fread(&input[i].terms, sizeof(int), 1, input[i].f);

	input[i].offsets = malloc(input[i].terms * sizeof(int));
	fread(input[i].offsets, sizeof(int), input[i].terms, input[i].f);

	if (input[i].terms > out.terms)
	    out.terms = input[i].terms;
    }
    printf("%d\n",out.terms);


    out.offsets = calloc(out.terms,sizeof(int));
    fwrite(&out.terms, sizeof(int), 1, out.f);
    fwrite(out.offsets, sizeof(int), out.terms, out.f);

    int *buf = NULL;


    int p;
    for (i = 0; i < out.terms; i++) {
	out.offsets[i] = ftell(out.f);
	for (p = 0; p < parts; p++) {
	    if (i < input[p].terms) {
		int size = chunk_size(input[p], i);
		buf = realloc(buf, sizeof(int) * size);

		fseek(input[p].f, input[p].offsets[i], SEEK_SET);
		fread(buf, sizeof(int), size, input[p].f);
		fwrite(buf, sizeof(int), size, out.f);
	    }
	}
    }

    fseek(out.f, sizeof(int), SEEK_SET);
    fwrite(out.offsets, sizeof(int), out.terms, out.f);

    for (p = 0; p < parts; p++) {
      fclose(input[p].f);
    }

    fclose(out.f);

}
C
1;
## vim: expandtab sw=2 ft=c
