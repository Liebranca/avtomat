#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:L1
# Token reader
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::l1;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;
  use Bpack;

  use Arstd::String;
  use Arstd::PM;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $TAG=>qr{

    ^\[

    (?<type>  . )
    (?<value> [^\]]+)


    \]\s

  }x;

  # two-way hash
  Readonly my $TAG_T=>{ map {(

    $ARG->[0]=>$ARG->[1],
    $ARG->[1]=>$ARG->[0],

  )} (

    ['*' => 'CMD'],
    ['`' => 'OPERA'],
    ['%' => 'STRING'],

    ['T' => 'TYPE'],
    ['F' => 'EXE'],

    ['r' => 'REG'],
    ['s' => 'SYM'],
    ['i' => 'NUM'],
    ['m' => 'MEM'],

    ['l' => 'LIST'],
    ['b' => 'BRANCH'],

  )};

# ---   *   ---   *   ---
# make tag regex

sub tagre($self,$type,$value) {


  # remember previously generated
  state $tab={
    BARE => qr{^[^\[].*}x,
    ANY  => $ANY_MATCH,

  };

  # ^so we can exit early ;>
  return $tab->{"$type:$value"}
  if exists $tab->{"$type:$value"};

  # ANY:  any token, tag or not
  # BARE: any non-tagged token
  return $tab->{BARE} if $type eq 'BARE';
  return $tab->{ANY}  if $type eq 'ANY';


  # type-check
  my $tag_t=$TAG_T->{$type};

  $self->throw_invalid_type($type)
  if ! defined $tag_t;


  # do escaping and build new regex
  $tag_t="\Q$tag_t";
  my $re=qr{^\[$tag_t$value\]\s};

  # ^save to table and give
  $tab->{"$type:$value"}=$re;


  return $re;

};

# ---   *   ---   *   ---
# turn current token into
# a tag of type

sub make_tag($self,$type,$src=undef) {

  # get ctx
  my $main=$self->{main};


  # get/validate sigil
  my $tag_t=$TAG_T->{$type};

  $self->throw_invalid_type($type)
  if ! defined $tag_t;


  # ^also invalid! throw, throw!
  $main->perr(

    "'%s' is a byte-sized tag-type, reserved "
  . "for internal use only; "

  . "use '%s' instead",

    args => [$type,$tag_t],


  ) if 1 < length $tag_t;


  # default to token if no src
  # default to char if no token!
  $src //= $main->{token};
  $src //= $main->{char};

  return "[$tag_t$src] ";

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_type($self,$type) {

  $self->{main}->perr(
    "invalid tag-type '%s'",
    args=>[$type],

  );

};

# ---   *   ---   *   ---
# ^undo

sub detag($self,$src=undef) {

  # default to current token
  my $main   = $self->{main};
     $src  //= $main->{token};

  # subst and give
  $src=~ s[$TAG][];
  return $src;

};

# ---   *   ---   *   ---
# joins the values of an array
# of tags of the same type
#
# gives a new tag holding all
# values joined together

sub cat_tags($self,@ar) {

  my $otype  = undef;
  my $ovalue = $NULLSTR;

  map {

    # disassemble tag
    my ($type,$value)=$self->read_tag($ARG);


    # cat value to result
    $otype  //= $type;
    $ovalue  .= $value;

    # enforce equal types
    $self->{main}->perr(
      "non-matching tag-types "
    . "cannot be catted!"

    ) if $type ne $otype;


  } @ar;


  # get non-internal type
  $otype=$TAG_T->{$otype};

  # make new and give
  return $self->make_tag($otype,$ovalue);

};

# ---   *   ---   *   ---
# token has [$tag] format?

sub read_tag($self,$src=undef) {

  $src //= $self->{main}->{token};

  return ($src=~ $TAG)
    ? ($+{type},$+{value})
    : undef
    ;

};

# ---   *   ---   *   ---
# ^give tag type/value if correct type

sub read_tag_t($self,$which,$src=undef) {

  my ($type,$value)=$self->read_tag($src);

  return ($type && $TAG_T->{$type} eq $which)
    ? $type
    : undef
    ;

};

sub read_tag_v($self,$which,$src=undef) {

  my ($type,$value)=$self->read_tag($src);

  return ($type && $TAG_T->{$type} eq $which)
    ? $value
    : undef
    ;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps '$self->read_tag_v'=>q(
  $self,$src=undef

),

map {["is_$ARG" => q['].(uc $ARG).q[',$src]]}
qw  (

  opera   list  string  cmd
  branch  num   type    sym

  reg     exe

);

# ---   *   ---   *   ---
# comments are just a special
# kind of string ;>

sub is_comment($self,$src=undef) {

  # get ctx
  my $main    = $self->{main};
  my $l0      = $main->{l0};
  my $charset = $l0->charset();

  # have string?
  my $value = $self->read_tag_v('STRING',$src);

  # ^if so, check that the string is marked
  # as a comment!
  return (

     defined $value
  && exists  $charset->{$value}

  && $charset->{$value} eq 'comment'

  ) ? $value : undef ;

};

# ---   *   ---   *   ---
# entry point
#
# classifies token if not
# already sorted!

sub parse($self,$src=undef) {


  # default src to current token
  my $main   = $self->{main};
     $src  //= $main->{token};

  # early exit if token already sorted
  return $src
  if defined $self->read_tag($src);


  # get ctx
  my $mc    = $main->{mc};

  my $CMD   = $main->{lx}->load_CMD();
  my $reg   = $mc->{bk}->{anima};
  my $ptr   = $mc->{bk}->{ptr};
  my $key   = $src;


  # is command?
  if((lc $key)=~ $CMD->{-re}) {
    $src=lc $src;
    $key='CMD';

  # is register?
  } elsif(defined (my $idex=$reg->tokin($key))) {
    $src=$idex;
    $key='REG';

  # is number?
  } elsif(defined (my $is_num=sstoi($key,0))) {
    $src=$is_num;
    $key='NUM';

  # is symbol name?
  } elsif(nref $src) {
    $key='SYM';

  # none of the above, give as-is
  } else {
    return $src;

  };


  return $self->make_tag($key,$src);

};

# ---   *   ---   *   ---
# look for name in scope

sub symbol_fetch($self,$src=undef) {


  # default to current token
  my $main   = $self->{main};
     $src  //= $main->{token};

  # attempt fetch
  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my $have  = $mc->search($src);


  return $have;

};

# ---   *   ---   *   ---
# make numerical repr for token

sub quantize($self,$src=undef) {


  # default to current token
  my $main   = $self->{main};
     $src  //= $main->{token};

  # skip on undef/null
  return null
  if ! defined $src ||! length $src;


  # have ptr?
  my $mc     = $main->{mc};
  my $ptrcls = $mc->{bk}->{ptr};

  return $src if $ptrcls->is_valid($src);


  # ^else unpack tag
  my ($type,$spec)=$self->read_tag($src);
  my $have=$self->detag($src);

  return $src if ! $type;
  $type=$TAG_T->{$type};


  # have plain value?
  if($type=~ qr{NUM|REG}) {
    return $spec;

  # have plain symbol name?
  } elsif($type eq 'SYM') {
    return $self->symbol_fetch($spec);


  # have string?
  } elsif($type eq 'STRING') {

    charcon \$have
    if $spec eq '"';

    return $have;

  # have executable binary? (yes ;>)
  } elsif($type eq 'EXE') {

    (exists $main->{engine})
      ? $main->{engine}->strexe($spec)
      : null
      ;


  # as for anything else...
  } else {
    nyi "<$type> quantization";

  };

};

# ---   *   ---   *   ---
1; # ret
