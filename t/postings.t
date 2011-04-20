#!/usr/bin/perl
use strict;
use warnings;
use File::Temp;
use Test::More;
use Test::File::Contents;
use v5.10;

use Tokenizer;
use Postings;

my $index_file = 'test';#tmpnam();

{
    my $tokenizer = TokenizerPtr::create(100);
    $tokenizer->set_docID(0);
    for my $token (0,1,2,3) {
        $tokenizer->add($token);
    }

    $tokenizer->set_docID(1);
    for my $token (0,1,5) {
        $tokenizer->add($token);
    }

    $tokenizer->sort;
    #$tokenizer->print;
    $tokenizer->write($index_file);
}

my $postings = PostingsPtr::create($index_file);
my $result = $postings->search(0);
isa_ok($result,"ResultPtr","the search result");
is_deeply([$postings->flatten($result)],[0,1],"searching for term 0");
is_deeply([$postings->flatten($postings->search(5))],[1],"searching for term 5");
is_deeply([$postings->flatten($postings->search(3))],[0],"searching for term 3");
is_deeply([$postings->flatten($postings->search(4))],[],"searching for non existent term 4");


done_testing;
