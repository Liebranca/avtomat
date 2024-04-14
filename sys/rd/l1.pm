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

  use Arstd::Array;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::PM;
  use Arstd::IO;

  use parent 'rd::layer';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.9;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  # cstruc values
  DEFAULT => sub {

    return {

      main => undef,
      defs => [],

      table => {

        map {(
          $ARG->[0]=>$ARG->[1],
          $ARG->[1]=>$ARG->[0],

        )} (

          ['%' => 'STR'],

          ['>' => 'SCP'],
          ['^' => 'EXP'],
          ['l' => 'LIST'],

        )

      },


    };

  },


  restruc => {
    open  => '\[',
    close => '\]',

  },

  anyre   => sub {$_[0]->mkre},

};

# ---   *   ---   *   ---
# build base types

sub build($self) {


  # get ctx
  my $main = $self->{main};
  my $l0   = $main->{l0};

  # make operator regex
  my $opr = re_eiths(

    $l0->spchars(),

    opscape => 1,
    capt    => 0,

  );


  # make operator detector
  $self->extend(OPR=>'`'=>sub {

    my $src   = $_[0];
    my $valid = $src=~ m[^$opr+$];

    return ($valid,$src,$NULLSTR);

  });


  # make number detector
  $self->extend(NUM=>'i'=>sub {

    my $src   = $_[0];
       $src   = sstoi $src,0;

    my $valid = defined $src;

    return ($valid,$src,$NULLSTR);

  });


  # make symbol detector
  $self->extend(SYM=>"'"=>sub {

    my $src   = $_[0];
    my $valid = ! ($src=~ $opr);

    return ($valid,$src,$NULLSTR);

  });


  return;


};

# ---   *   ---   *   ---
# adds type definitions to tables

sub extend($self,$key,$char,$fn) {

  # add to typename table
  my $dst=$self->{table};

  $dst->{$key}  = $char;
  $dst->{$char} = $key;

  # add to pattern table
  $dst=$self->{defs};
  push @$dst,$key=>$fn;

  $self->update_detect();

  return;

};

# ---   *   ---   *   ---
# regex tempate

sub mkre($self,@args) {

  my $class=(length ref $self)
    ? ref $self
    : $self
    ;

  my $struc=$class->restruc;


  # specific pattern requested?
  return (@args)


    # if so give pattern to match args
    ? qr{^

      $struc->{open}

      (?<type> $args[0])
      (?<spec> $args[1])


      $struc->{close}\s

      (?<data> .*)

    }x


    # ^else give global
    : qr{^

      $struc->{open}

      (?<type>  .)
      (?<spec> [^$struc->{close}]+)


      $struc->{close}\s

      (?<data> .*)

    }x;


};

# ---   *   ---   *   ---
# make tag regex

sub re($self,$type,$spec) {


  # remember previously generated
  state $tab={
    BARE => qr{^[^$self->restruc()->{open}].*}x,
    ANY  => $ANY_MATCH,

  };

  # ^so we can exit early ;>
  return $tab->{"$type:$spec"}
  if exists $tab->{"$type:$spec"};

  # ANY:  any token, tag or not
  # BARE: any non-tagged token
  return $tab->{BARE} if $type eq 'BARE';
  return $tab->{ANY}  if $type eq 'ANY';


  # type-check
  my $tag_t=$self->{table}->{$type};

  $self->throw_invalid_type($type)
  if ! defined $tag_t;


  # build new and save to table
  my $re=$self->mkre("\Q$tag_t",$spec);
  $tab->{"$type:$spec"}=$re;

  return $re;

};

# ---   *   ---   *   ---
# add typing data to token

sub tag($self,$type,$src=undef) {


  # get ctx
  my $main = $self->{main};
  my $l0   = $main->{l0};


  # get/validate sigil
  my $tag_t=$self->{table}->{$type};

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
  $src //= $self->{token};
  $src //= $l0->{char};

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

sub untag($self,$src=undef) {

  $src //= $self->{token};

  return ($src=~ $self->anyre)

    ? {

      type=>$+{type},
      spec=>$+{spec},
      data=>$+{data}

    } : () ;

};

# ---   *   ---   *   ---
# joins the values of an array
# of tags of the same type
#
# gives a new tag holding all
# values joined together

sub cat($self,@ar) {

  my $otype = undef;
  my $ospec = $NULLSTR;
  my $odata = $NULLSTR;

  map {

    # disassemble typed token
    my ($have)=$self->untag($ARG);

    # enforce equal types
    $self->{main}->perr(
      "non-matching tag-types "
    . "cannot be catted!"

    ) if $have->{type} ne $otype;


    # cat spec/data to result
    $otype //= $have->{type};
    $ospec  .= $have->{spec};
    $odata  .= $have->{data};


  } @ar;


  # get non-internal type
  $otype=$self->{table}->{$otype};

  # make new and give
  return $self->tag($otype,$ospec) . $odata;

};

# ---   *   ---   *   ---
# ^converts type to user v

sub xlate($self,$src=undef) {

  my $have=$self->untag($src);
  return 0 if ! $have;

  my $type=$have->{type};

  $have->{type}=$self->{table}->{$type};
  return $have;

};

# ---   *   ---   *   ---
# ^give descriptor if correct type

sub typechk($self,$expect,$src=undef) {


  # have typed token?
  my $tab  = $self->{table};
  my $have = $self->untag($src);

  return 0 if ! $have;


  # ^yep, compare
  my $type=$have->{type};

  return ($tab->{$type} eq $expect)
    ? $have
    : 0
    ;

};

# ---   *   ---   *   ---
# typecheck series!

sub switch($self,$src,%ev) {


  # disassemble
  my $have = $self->untag($src);
  my $def  = $ev{DEF};

  delete $ev{DEF};


  # walk [type=>F] array
  map {

    my $type = $ARG;
    my $fn   = $ev{$type};

    if($have->{type} eq $type) {
      return $fn->($self,$have)

    };

  } keys %ev if $have;


  # give default on no match!
  return ($def && $have)
    ? $def->($self,$have)
    : ()
    ;

};

# ---   *   ---   *   ---
# untag and stringify!

sub stirr($self,$src=undef) {

  return $self->switch(

    $src,

    STR=>sub {$_[0]->{data}},
    DEF=>sub {"$_[0]->{spec}$_[0]->{data}"},

  );

};

# ---   *   ---   *   ---
# comments are just a special
# kind of string ;>

sub is_comment($self,$src=undef) {

  # get ctx
  my $main    = $self->{main};
  my $l0      = $main->{l0};
  my $charset = $l0->charset();

  # have string?
  my $have=$self->typechk(STR=>$src);
  return if ! $have;


  # ^if so, check that the string is marked
  # as a comment!
  my $spec=$have->{spec};

  return (
     exists $charset->{$spec}
  && $charset->{$spec} eq 'com'

  ) ? $have : () ;

};

# ---   *   ---   *   ---
# entry point
#
# classifies token if not
# already sorted!

sub detect($self,$src) {


  # already sorted, move on
  return $src if $src=~ $self->anyre;


  # pass data through F and give
  my ($key,$spec,$data)=
    $self->{detector}->($src);

  return ($key ne 'DEF')
    ? $self->tag($key,$spec) . $data
    : $src
    ;

};

# ---   *   ---   *   ---
# rebuilds the pattern matcher ;>

sub update_detect($self) {


  # array as hash
  my @k = array_keys   $self->{defs};
  my @v = array_values $self->{defs};

  # ^make walking F
  $self->{detector}=sub ($src) {

    for my $i(0..$#k) {

      # get type => method
      my $key=$k[$i];
      my $chk=$v[$i];

      # ^give if data matches type
      my ($valid,@have)=
        $chk->($src);

      return $key,@have if $valid;

    };

    # else give back input!
    return 'DEF',$src,$NULLSTR;

  };

};

# ---   *   ---   *   ---

sub parse($self,$src,%O) {


  # early exit if token already sorted
  return $src
  if $self->untag($src);


  # defaults
  $O{nocmd} //= 0;

  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};

  my $CMD   = $main->{lx}->load_CMD();
  my $reg   = $mc->{bk}->{anima};
  my $ptr   = $mc->{bk}->{ptr};
  my $key   = $src;


  # is command?
  if(! $O{nocmd} && (lc $key)=~ $CMD->{-re}) {
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


  return $self->tag($key,$src);

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
  my ($type,$spec)=$self->untag($src);
  my $have=$self->detag($src);


  return $src if ! $type;
  $type=$self->{table}->{$type};


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
