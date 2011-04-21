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
    [0]
);

{
    my $tokenizer = TokenizerPtr::create(100);
    for my $docID (0..$#docs) {
        $tokenizer->set_docID($docID);
        for my $tokID (@{$docs[$docID]}) {
            $tokenizer->add($tokID);
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
    my $phrase_result = $postings->phrase($a,$b);
    is_deeply([$postings->flatten($phrase_result)],[0,1]);
}
{
    my $a = $postings->search(2);
    my $b = $postings->search(1);
    my $phrase_result = $postings->phrase($a,$b);
    is_deeply([$postings->flatten($phrase_result)],[1]);
}
{
    my $a = $postings->search(2);
    my $b = $postings->search(2);
    my $phrase_result = $postings->phrase($a,$b);
    is_deeply([$postings->flatten($phrase_result)],[]);
}


done_testing;
