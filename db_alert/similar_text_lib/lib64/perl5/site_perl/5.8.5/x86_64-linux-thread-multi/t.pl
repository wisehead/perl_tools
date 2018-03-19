#! /opt/perl5/bin/perl

BEGIN
{
    push @INC, "/home/mysql/alert/similar_text";
}

use ExtUtils::testlib;
use similar_text;


print "similarity1: ", similar_text::similar_text("WITH MYSQL", "PHP IS GREAT"), "\n";
print "similarity2: ", similar_text::similar_text("PHP IS GREAT", "WITH MYSQL"), "\n";
