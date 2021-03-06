#!/usr/bin/perl
use strict;
use warnings;
use v5.10;

use File::Temp;
use Test::More;

use Tokenizer;
use Postings;

my $index_file = tmpnam();

my @docs = (
    [ #0
        0,0,0,0,0,0,
        4,0,0,0,0,0,
        0,0,0,0,0,0,
        0,0,0,5,0,0,
        0,0,0,0,0,0
    ],
    [ #1
        0,0,0,1,0,0,
        0,0,0,0,0,0,
        0,0,2,1,0,0,
        0,0,0,0,2,0,
        0,1,2,0,0,0
    ],
    [4,5,6], #2
    [ #3
        0,0,0,1,0,0,
        0,0,0,0,1,0
    ],
    [5,4,2], #4
    [0,0,6,5], #5
    [ #6
        0,0,0,6,0,0,
        4,0,0,0,0,0,
        0,0,0,0,0,0,
        0,0,0,0,0,0,
        0,0,0,5,0,0
    ],
);

{
    my $tokenizer = TokenizerPtr::create(1000);
    my $pos = 0;
    for my $docID (0..$#docs) {
        for my $tokID (@{$docs[$docID]}) {
            $tokenizer->add($tokID,$docID,$pos++);
        }
    }

    $tokenizer->sort;
#    $tokenizer->print;
    $tokenizer->write($index_file);
}

my $postings = PostingsPtr::create($index_file);

{
    my $a = $postings->search(1);
    my $b = $postings->search(2);
    is_deeply($a->array,[1,3],"just searching for 1");
    is_deeply($b->array,[1,4],"just searching for 2");
    is_deeply($a->and($b)->array,[1],"searching for 1 & 2");
}
{
    my $a = $postings->search(4);
    my $b = $postings->search(5);
    my $c = $postings->search(6);

    is_deeply($a->array,[0,2,4,6],"just searching for 4");
    is_deeply($b->array,[0,2,4,5,6],"just searching for 5");
    is_deeply($c->array,[2,5,6],"just searching for 6");
}
{
    my $a = $postings->search(2);
    my $b = $postings->search(4);

    is_deeply($a->or($b)->array,[0,1,2,4,6],"searching for 1|4");
}
{
    my $a = $postings->search(3);
    my $b = $postings->search(2);
    is_deeply($a->or($b)->array,[1,4],"just searching for 3|2");
    is_deeply($b->or($a)->array,[1,4],"just searching for 2|3");
}
{
    my $a = $postings->search(3);
    my $b = $postings->search(2);
    is_deeply($a->and($b)->array,[],"just searching for 3&2");
    is_deeply($b->and($a)->array,[],"just searching for 2&3");
}


done_testing;
