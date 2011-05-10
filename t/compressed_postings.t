#!/usr/bin/perl
use strict;
use warnings;
use File::Temp qw(tempfile tmpnam);
use Test::More;

use Tokenizer;
use Postings;

use Index::Compress;

my $index_file = tmpnam();

my ($fh,$compressed_index_file) = tempfile(SUFFIX=>'.compressed');
close($fh);

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

    $tokenizer->set_docID(2);
    $tokenizer->add(7);
    $tokenizer->add(8);
    $tokenizer->pos_move(-1);
    $tokenizer->add(9);

    $tokenizer->sort;
    #$tokenizer->print;
    $tokenizer->write($index_file);
    Index::Compress::compress_file($index_file, $compressed_index_file);
}

my $postings = PostingsPtr::create($compressed_index_file);
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
