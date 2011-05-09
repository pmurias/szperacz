#!/usr/bin/perl
use Inline C=><<'C';
#include <stdio.h>
SV* read_morfologik(char* file) {
  HV* morph = newHV();
  FILE* f = fopen(file,"r");
  if (!f) perror("opening morfologik");
  char line[200];
  while (!feof(f)) {
    fgets(line,200,f);

    int i=0;
    for (i=0;line[i] != ' ';i++);
    int key_end = i;

    for (i++;line[i] != ' ' && line[i] != '\n';i++);
    SV* first = newSVpv(line+key_end+1,i-key_end-1);
    SV* val;
    if (line[i] == ' ') {
        AV* all = newAV();
        av_push(all,first);
        while (line[i] != '\n') {
          int place = i+1;
          for (i++;line[i] != ' ' && line[i] != '\n';i++);
          av_push(all,newSVpv(line+place,i-place));
        }
        val = newRV_noinc(all);
    } else {
        val = first;
    }

//    printf("<%s> %d\n",line+key_end+1,i-key_end-1);

    hv_store(morph, line, key_end, val , 0);

  }
  return newRV_noinc(morph);
}
C
read_morfologik("morfologik_do_wyszukiwarek.txt");
#use Data::Dumper;
#print Dumper();
## vim: expandtab sw=2 ft=c
