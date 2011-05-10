#!/usr/bin/perl
use strict;
use warnings;
use File::Temp;
use Test::More;

use Tokenizer;
use Postings;

my $index_file = tmpnam();

{
    my $tokenizer = TokenizerPtr::create(100);
    my $docID;
    my $pos = 0;
    $docID = 0;
    for my $token (0,1,2,3) {
        $tokenizer->add($token,$docID,$pos++);
    }

    $docID = 1;
    for my $token (0,1,5) {
        $tokenizer->add($token,$docID,$pos++);
    }

    $tokenizer->add(7,2,$pos++);
    $tokenizer->add(8,2,$pos);
    $tokenizer->add(9,2,$pos++);

    $tokenizer->sort;
    #$tokenizer->print;
    $tokenizer->write($index_file);
}

my $postings = PostingsPtr::create($index_file);
my $result = $postings->search(0);
isa_ok($result,"ResultPtr","the search result");
is_deeply($result->array,[0,1],"searching for term 0");
is_deeply($postings->search(5)->array,[1],"searching for term 5");
is_deeply($postings->search(3)->array,[0],"searching for term 3");
is_deeply($postings->search(4)->array,[],"searching for non existent term 4");

is_deeply([$postings->search(7)->all],[2,1,7]);
is_deeply([$postings->search(8)->all],[2,1,8]);
is_deeply([$postings->search(9)->all],[2,1,8]);


done_testing;
