#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::File::Contents;
use File::Temp qw(:POSIX);
use Tokenizer;
my $tokenizer = TokenizerPtr::create(20);
pass "lives after calling create";

my $pos = 0;
my $docID = 13;
for my $token (100,234,534,12) {
    $tokenizer->add($token,$docID,$pos++);
}

my $file = tmpnam();

$tokenizer->sort;
$tokenizer->write($file);

file_contents_ne $file,"",{encoding => ":bytes"},"the file written by the tokenizer is not empty";
done_testing;
