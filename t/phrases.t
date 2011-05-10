#!/usr/bin/perl
use strict;
use warnings;
use File::Temp;
use Test::More;

use Tokenizer;
use Postings;

my $index_file = tmpnam();

my @docs = (
    [
        0,0,0,1,0,0,
        0,0,0,0,0,0,
        0,0,1,2,0,0,
        0,0,0,1,2,0,
        0,1,2,0,0,0
    ],
    [
        0,0,0,1,0,0,
        0,0,0,0,0,0,
        0,0,2,1,0,0,
        0,0,0,0,2,0,
        0,1,2,0,0,0
    ],
    [
        0,0,0,1,0,0,
        0,0,0,0,2,0
    ],
    [0],
    [0,0,0,0,2],
    [1,0,0,0,2],
    [1,0,0,0,0],
    [0,0,0,0,2],
);

{
    my $tokenizer = TokenizerPtr::create(100);

    my $pos = 0;
    for my $docID (0..$#docs) {
        for my $tokID (@{$docs[$docID]}) {
            $tokenizer->add($tokID,$docID,$pos++);
        }
    }

    $tokenizer->sort;
    #$tokenizer->print;
    $tokenizer->write($index_file);
}

my $postings = PostingsPtr::create($index_file);

{
    my $a = $postings->search(1);
    my $b = $postings->search(2);
    is_deeply($postings->phrase($a,$b)->array,[0,1]);
}
{
    my $a = $postings->search(2);
    my $b = $postings->search(1);
    is_deeply($postings->phrase($a,$b)->array,[1]);
}
{
    my $a = $postings->search(2);
    my $b = $postings->search(2);
    is_deeply($postings->phrase($a,$b)->array,[]);
}


done_testing;
