#! /usr/bin/perl
#
use warnings;
use strict;

use FindBin;

@ARGV == 2
  or die "Usage: $FindBin::Script FILE_C FILE_H\n";

my ($file_c, $file_h) = @ARGV;

my $poly = 0xedb88320;
my $init = 0x0;


sub gen_lookup {
    my ($poly) = @_;

    my @lookup;

    for (my $i = 0; $i < 256; ++$i) {
        my $crc32 = $i;
        for (my $j = 8; $j > 0; --$j) {
            if ($crc32 & 0x1) {
                $crc32 = ($crc32 >> 1) ^ $poly;
            } else {
                $crc32 >>= 1;
            }
        }
        push @lookup, $crc32;
    }

    return \@lookup;
}


my $lookup = gen_lookup($poly);

my $table;
while (@$lookup) {
    $table .= join(', ',
                  map { sprintf("0x%08xU", $_) } splice(@$lookup, 0, 6));
    $table .= ",\n  ";
}
$table =~ s/,\n  \Z//;

my $gen_comment = <<"EOF";
/*
  This file was generated with $FindBin::Script.

  Do not edit.
*/
EOF

(my $prototype = <<"EOF") =~ s/\n\Z//;
unsigned int
compute_crc32(const char *s, size_t len)
EOF


open(my $fc, '>', $file_c)
  or die "open(> $file_c): $!";

print $fc <<"EOF";
$gen_comment
#include "$file_h"


static const unsigned int crc32lookup[256] = {
  $table
};


$prototype
{
  const char *end = s + len;
  unsigned int crc32 = ~@{[ sprintf("0x%08xU", $init) ]};

  while (s < end)
    {
      unsigned int index = (crc32 ^ (unsigned int) *s) & 0x000000ffU;
      crc32 = (crc32 >> 8) ^ crc32lookup[index];
      ++s;
    }

  return (~crc32);
}
EOF

close($fc)
  or die "close($file_c): $!";


my $guard = uc $file_h;
$guard =~ s/[^[:alnum:]_]/_/g;

open(my $fh, '>', $file_h)
  or die "open(> $file_h): $!";


print $fh <<"EOF";
$gen_comment
#ifndef $guard
#define $guard 1

#include <stddef.h>


extern
$prototype;


#endif /* ! $guard */
EOF

close($fh)
  or die "close($file_h): $!";
