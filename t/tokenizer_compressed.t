#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::File::Contents;
use File::Temp qw(:POSIX);
use Tokenizer;
my $tokenizer = TokenizerPtr::create(20);
pass "lives after calling create";

$tokenizer->set_docID(13);
for my $token (100,234,534,12) {
    $tokenizer->add($token);
}

my $file = tmpnam();

$tokenizer->sort;
$tokenizer->write_compressed($file);

file_contents_ne $file,"",{encoding => ":bytes"},"the file written by the tokenizer is not empty";
done_testing;
