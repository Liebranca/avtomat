#!/usr/bin/perl
# ---   *   ---   *   ---
# SHADOWLIB
# Shady pre-compiled stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package shadowlib;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Carp;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub ipret_decls($line) {

  state $COMMA=qr{,};
  state $EQUAL=qr{\*=>};

  my $value_table={order=>[]};
  my @elems=split m/$COMMA/,$line;

# ---   *   ---   *   ---

  for my $elem(@elems) {
    my ($key,$value)=split m/$EQUAL/,$elem;

    $key="\Q$key";
    $key=$key.'\b';
    $key=qr{$key};

# ---   *   ---   *   ---

    if($value=~ m/\$_\[(\d)\]/) {
      $value=${^CAPTURE[0]};

    } else {
      $value=eval($value);

    };

# ---   *   ---   *   ---

    $value_table->{$key}=$value;
    push @{$value_table->{order}},$key;

  };

  return $value_table;

};

# ---   *   ---   *   ---

sub take($imports) {

  my $table={};

# ---   *   ---   *   ---
# walk the imports list

  for my $libpath(keys %$imports) {
    my @modules=@{$imports->{$libpath}};

    for my $module(@modules) {

      # ensure table is updated
      `perl -e "use lib '$libpath';use $module;"`;

      my $lib="$libpath.$module";

      # read table
      open my $FH,'<',
      $lib or croak $ERRNO;

# ---   *   ---   *   ---
# process entries

      while(my $symname=readline $FH) {

        chomp $symname;
        if(!length $symname) {last};

        my $mem=readline $FH;chomp $mem;
        my $args=readline $FH;chomp $args;
        my $code=readline $FH;chomp $code;

        $mem=ipret_decls($mem);
        $args=ipret_decls($args);

# ---   *   ---   *   ---
# save symbol to table

        my $sbl=bless {

          id=>$symname,

          mem=>$mem,
          code=>$code,
          args=>$args,

        },'shadowlib::symbol';

        $table->{$symname}=$sbl;

# ---   *   ---   *   ---
# close file and repeat

      };

      close $FH or croak $ERRNO;

# ---   *   ---   *   ---
# give back symbol table

    };
  };

  my @names=sort {
    (length $a)<=(length $b)

  } keys %$table;

  my $re='\b('.(join '|',@names).')\b';

  $table->{re}=qr{$re};
  return $table;

};

# ---   *   ---   *   ---
1; # ret

# ---   *   ---   *   ---

package shadowlib::symbol;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---

sub paste($sbl,@passed) {

  my $mem=$sbl->{mem};
  my $args=$sbl->{args};
  my $code=$sbl->{code};

  for my $key(@{$mem->{order}}) {
    my $value=$mem->{$key};
    $code=~ s/$key/$value/;

  };

  for my $key(@{$args->{order}}) {
    my $value=$args->{$key};
    $value=$passed[$value];

    $code=~ s/$key/$value/;

  };

  $code=~ s/^\{|;?\s*\}\s*;?$//sg;

  return $code;

};

# ---   *   ---   *   ---
