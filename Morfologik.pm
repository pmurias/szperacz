package Morfologik;
use strict;use warnings;
use v5.10;
## use Inline C=><<'C';
## #include <stdio.h>
## SV* read_morfologik(char* file) {
##   HV* morph = newHV();
##   FILE* f = fopen(file,"r");
##   if (!f) perror("opening morfologik");
##   char line[200];
##   while (!feof(f)) {
##     fgets(line,200,f);
## 
##     int i=0;
##     for (i=0;line[i] != ' ';i++);
##     int key_end = i;
## 
##     for (i++;line[i] != ' ' && line[i] != '\n';i++);
##     SV* first = newSVpv(line+key_end+1,i-key_end-1);
##     SV* val;
##     if (line[i] == ' ') {
##         AV* all = newAV();
##         av_push(all,first);
##         while (line[i] != '\n') {
##           int place = i+1;
##           for (i++;line[i] != ' ' && line[i] != '\n';i++);
##           av_push(all,newSVpv(line+place,i-place));
##         }
##         val = newRV_noinc(all);
##     } else {
##         val = first;
##     }
## 
## //    printf("<%s> %d\n",line+key_end+1,i-key_end-1);
## 
##     hv_store(morph, line, key_end, val , 0);
## 
##   }
##   return newRV_noinc(morph);
## }
## C

sub read_morfologik {
    my $file = shift;
    my %morfologik;
    open(my $morfologik,$file // 'morfologik_do_wyszukiwarek.txt');
    binmode $morfologik, ':encoding(UTF-8)';
    while (my $word = <$morfologik>) {
        my @words = split (/\W/,$word);
        if (scalar @words == 2) {
            $morfologik{$words[0]} = $words[1];
        } else {
            my $key = shift @words;
            $morfologik{$key} = [@words];
        }
    }
    \%morfologik;
}

my $morfologik;
sub load {
    my $file = shift;
    $morfologik = read_morfologik($file // "morfologik_do_wyszukiwarek.txt");
    #print Dumper($morfologik);
    #for my $key (keys %{$morfologik}) {
    #    print $key," ",Dumper($morfologik->{$key}),"\n";
    #}
}
sub get {
    my ($key) = @_;
    load() unless $morfologik;
    #use Data::Dumper;
    #print Dumper($morfologik);
    #print "entry for <$key>",Dumper($morfologik->{$key}),"\n";
    if (ref $morfologik->{$key} eq 'ARRAY') {
        $morfologik->{$key};
    } elsif ($morfologik->{$key}) {
        [$morfologik->{$key}];
    } else {
        #warn $key," ",$morfologik{$key};
        [$key];
    }
}
1;
