#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO
# $ syntax defs
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package Lang::peso;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys';

  use Style;

  use Arstd::Array;
  use Arstd::Re;
  use Arstd::IO;

  use Type::MAKE;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---

BEGIN {

my $NUMS=Lang::Def->DEFAULT->{nums};
$NUMS->{'(\$[0-9A-F]+)'}='\&hstoi';

# ---   *   ---   *   ---
# builtins and functions, group A

  Readonly my $BUILTIN=>[re_eiths(

    [qw(

      cpy mov wap

      pop push
      shift unshift

      inc dec cl

      mem fre kin
      sow reap

      exit

    )],

    insens => 1,
    bwrap  => 1,

  )];

# ---   *   ---   *   ---
# reserved names

  Readonly my $RESNAMES=>[re_eiths(

    [qw(

      self other null non
      stdin stdout stderr

    )],

    insens => 1,
    bwrap  => 1,

  )];

  Readonly my $DIRECTIVE=>[re_eiths(

    [qw(

      reg rom clan proc
      entry atexit

      case nocase

      def undef redef
      lib use

    )],

    insens => 1,
    bwrap  => 1,

  )];

# ---   *   ---   *   ---

  Readonly my $FCTL=>[re_eiths(

    [qw(

      jmp jif eif
      on from or off

      call ret rept
      wait sys stop

    )],

    insens => 1,
    bwrap  => 1,

  )];

# ---   *   ---   *   ---

  Readonly my $INTRINSIC=>[re_eiths(

    [qw(

      beq blk
      wed unwed

      ipol lis
      in out xform

      defd

    )],

    insens => 1,
    bwrap  => 1,

  )];

  Readonly my $SPECIFIER=>[re_eiths(

    [qw(

      ptr fptr
      str buf tab

      re

    )],

    insens => 1,
    bwrap  => 1,

  )];

# ---   *   ---   *   ---

Lang::peso->new(

  name  => 'peso',

  ext   => '\.(pe|p3|rom)$',
  hed   => '[^A-Za-z0-9_]+[A-Za-z0-9_]*;',
  mag   => '$ program',

  nums  => $NUMS,

# ---   *   ---   *   ---

  types      => Type::MAKE->ALL_FLAGS,

  specifiers => [@$SPECIFIER],
  resnames   => [@$RESNAMES],
  intrinsics => [@$INTRINSIC],
  directives => [@$DIRECTIVE],
  fctls      => [@$FCTL],
  builtins   => [@$BUILTIN],

# ---   *   ---   *   ---

  fn_key=>re_insens('proc'),

  fn_decl=>q{

    \b$:sbl_key;> \s+

    (?<attrs> $:types->re;> \s+)*\s*
    (?<name> $:names;>)\s*

    [;]+

    (?<scope>
      (?<code>

        (?: (?:ret|exit) \s+ [^;]+)
      | (?: \s* [^;]+; \s* (?&scope))

      )*

    )

    \s*[;]+

  },

# ---   *   ---   *   ---

)};

# ---   *   ---   *   ---
# sets up nodes such that:
#
# >clan
# \-->reg
# .  \-->proc
# .
# .
# \-->reg
# .
# >clan

sub hier_sort($self,$tree) {

  my $root=$tree;

  my $anchor=$root;
  my @anchors=($root,undef,undef,undef);

  my $scopers=qr/\b(clan|reg|rom|proc)\b/i;

# ---   *   ---   *   ---
# iter tree

  for my $leaf(@{$tree->{leaves}}) {
    if($leaf->{value}=~ $scopers) {
      my $match=$1;

# ---   *   ---   *   ---

      if(@anchors) {
        if($match=~ m[^clan$]i) {
          $anchors[1]=$leaf;
          $anchor=$root;

# ---   *   ---   *   ---

        } elsif($match=~ m[^(?:reg|rom)$]i) {
          $anchor=$anchors[1];
          $anchor//=$anchors[0];
          @anchors[2]=$leaf;

# ---   *   ---   *   ---

        } elsif($match=~ m[^proc$]i) {
          $anchor=$anchors[2];
          $anchor//=$anchors[1];
          $anchor//=$anchors[0];

          @anchors[3]=$leaf;

        };

# ---   *   ---   *   ---
# move node and reset anchor

      };

      if(

         defined $anchor
      && $leaf->{parent} ne $anchor

      ) {

        ($leaf)=$leaf->{parent}->pluck($leaf);
        $anchor->pushlv($leaf);

      };

      $anchor=$leaf;

# ---   *   ---   *   ---
# node doesn't modify anchor

    } elsif($leaf->{parent} ne $anchor) {
      ($leaf)=$leaf->{parent}->pluck($leaf);
      $anchor->pushlv($leaf);

    };

  };

};

# ---   *   ---   *   ---
1; # ret
