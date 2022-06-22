#!/usr/bin/perl
# ---   *   ---   *   ---
# FNDMTL
# It's fundamentals
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::fndmtl;
  use strict;
  use warnings;

sub ptr_decl($) {

  my ($self,$tree)=@_;

  my $type=($tree->branch_values('^type$'))[0];

  print "$type\n";

  my @names=$tree->branch_values('^name$');
  my @values=$tree->branch_values('^value$');

# ---   *   ---   *   ---
# case A: more names than values

  if(@names>@values) {

    my $i=@values;
    while($i<@names) {
      push @values,'null';
      $i++;

    };

# ---   *   ---   *   ---
# case B: more values than names

  } elsif(@names<@values) {

    my $i=@names;
    my $j=1;
    while($i<@values) {
      push @names,"$names[-1]+$j";
      $i++;$j++;

    };
  };

# ---   *   ---   *   ---

  my %ptrs;
  @ptrs{@names}=@values;

  for my $key(keys %ptrs) {

    print "$key=>$ptrs{$key}\n";

  };

# ---   *   ---   *   ---

#$tree->prich();

};

# ---   *   ---   *   ---
1; # ret
