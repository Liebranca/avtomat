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
package shwl;

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
# ROM

  use constant {

    EXT_RE=>qr{[.].*$},
    FNAME_RE=>qr{\/([_\w][_\w\d]*)$},

    CUT_FMAT=>':__%s_CUT_%i__:',
    CUT_RE=>':__\w+_CUT_(\d+)__:',

# ---   *   ---   *   ---

    STR_RE=>qr{

      "
      (?: \\" | [^"] )+

      "

    }x,

# ---   *   ---   *   ---

    CHR_RE=>qr{

      '
      (?: \\' | [^'] )+

      '

    }x,

# ---   *   ---   *   ---

    ARGS_RE=>qr{

      (?<parens>

      \s*\(

        (?<arg> [^()]* | (?&parens) )

      \s*\)

      )

    }x,

# ---   *   ---   *   ---

    IS_PERLMOD=>qr{[.].pm$},

  };

# ---   *   ---   *   ---
# global state

  my $STRINGS={};
  sub STRINGS {return $STRINGS};

# ---   *   ---   *   ---
# utility funcs

sub cut($string_ref,$name,$pat) {

  my $matches=[];

# ---   *   ---   *   ---
# replace pattern with placeholder

  while($$string_ref=~ s/($pat)/#:cut;>/s) {

    my $v=${^CAPTURE[0]};
    my $token=q{};

# ---   *   ---   *   ---
# construct a peso-style :__token__:

    # repeats aren't saved twice
    if(exists $STRINGS->{$v}) {
      $token=$STRINGS->{$v};

    # hash->{data}=token
    # hash->{token}=data
    } else {
      $token=sprintf CUT_FMAT,
        $name,int(keys %$STRINGS);

      $STRINGS->{$v}=$token;
      $STRINGS->{$token}=$v;

    };

# ---   *   ---   *   ---
# put the token in place of placeholder

    $$string_ref=~ s/#:cut;>/$token/;
    push @$matches,$token;

  };

  return $matches;

};

# ---   *   ---   *   ---

sub stitch($string_ref) {

  while($$string_ref=~ m/(${\CUT_RE})/) {
    my $key=${^CAPTURE[0]};
    my $value=$STRINGS->{$key};

    $$string_ref=~ s/${key}/$value/;

  };

  return;

};

# ---   *   ---   *   ---

sub darkside_of($the_force) {
  $the_force=~ s/${\EXT_RE}//;
  $the_force=~ s/${\FNAME_RE}/\/\.$1/;

  return $the_force;

};

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
# fetches symbol table from %INC
# by reading /.lib files

sub getlibs() {

  my $table={};

# ---   *   ---   *   ---
# filter out %INC

  my @imports=();
  for my $module(keys %INC) {

    my $fpath=darkside_of($INC{$module});
    if(-e $fpath) {push @imports,$fpath};

  };

# ---   *   ---   *   ---
# walk the imports list

  for my $fpath(@imports) {

    open my $FH,'<',
    $fpath or croak $ERRNO;

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

      },'shwl::sbl';

      $table->{$symname}=$sbl;

# ---   *   ---   *   ---
# close file and repeat

    };

    close $FH or croak $ERRNO;

# ---   *   ---   *   ---
# give back symbol table

  };

  my @names=sort {
    (length $a)<=(length $b)

  } keys %$table;

  my $re='\b('.(join '|',@names).')\b';

  $table->{re}=qr{$re}xs;

  return $table;

};

# ---   *   ---   *   ---
1; # ret

# ---   *   ---   *   ---

package shwl::sbl;

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
