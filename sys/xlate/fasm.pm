#!/usr/bin/perl
# ---   *   ---   *   ---
# XLATE FASM
# Virtual to native!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package xlate::fasm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Type;

  use Fmat;
  use St;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

St::vconst {


  metains  => qr{^(?:
    self

  )$}x,

  instab => {

    ld    => 'mov',
    lz    => 'cmovz',

    _cmp  => 'cmp',

  },

  register => sub {

    my $class=$_[0];

    return {

      0x0 => $class->rX('a'),
      0x1 => $class->rX('12'),
      0x2 => $class->rX('c'),
      0x3 => $class->rX('13'),
      0x4 => $class->rX('di'),
      0x5 => $class->rX('si'),
      0x6 => $class->rX('d'),
      0x7 => $class->rX('10'),

      0x8 => $class->rX('8'),
      0x9 => $class->rX('9'),

      0xA => $class->rX('sp'),
      0xB => $class->rX('bp'),

      0xC => $class->rX('b'),
      0xD => $class->rX('15'),

      0xE => $class->rX('14'),
      0xF => $class->rX('11'),

    };

  },

};

# ---   *   ---   *   ---
# A9M registers to x86

sub rX($class,$name) {


  # name in [rax,rbx,rcx,rdx] ?
  if($name=~ qr{^(?:a|b|c|d)$}) {

    return {

      qword => "r${name}x",
      dword => "e${name}x",
      word  => "${name}x",
      byte  => "${name}l",

    };


  # name in [rdi,rsi,rsp,rbp] ?
  } elsif($name=~ qr{^(?:di|si|sp|bp)$}) {

    return {

      qword => "r${name}",
      dword => "e${name}",
      word  => "${name}",
      byte  => "${name}l",

    };


  # name in [r8-15] !
  } else {

    return {

      qword => "r${name}",
      dword => "r${name}d",
      word  => "r${name}w",
      byte  => "r${name}b",

    };

  };

};

# ---   *   ---   *   ---
# A9M data to x86

sub data_decl($class,$type) {

  map {{

    byte  => 'db',
    word  => 'dw',
    dword => 'dd',
    qword => 'dq',

    xword => 'dq',
    yword => 'dq',
    zword => 'dq',

  }->{$ARG}} typeof $type->{sizeof};

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$main) {
  return bless {main=>$main},$class;

};

# ---   *   ---   *   ---
# get symbol name

sub symname($src,$key='id') {

  my @path=@{$src->{$key}};
  my $name=shift @path;

  return join '_',@path,$name;

};

# ---   *   ---   *   ---
# decompose memory operand

sub addr_collapse($tree) {

  my $opera = qr{^(?:\*|\/)$};
  my @have  = map {

    my $neg = 0;
    my @out = ();

    # have fetch?
    if(exists $ARG->{imm}) {
      @out = symname $ARG,'id';
      $neg = $ARG->{neg};

    # have value!
    } else {
      @out = $ARG->{id};
      $neg = $ARG->{neg};

    };

    @out = ('-',@out) if $neg;
    @out;


  } @$tree;


  my @out=();
  while(@have) {

    my $x=shift @have;
    if($x=~ $opera) {
      my ($lh,$rh)=(shift @have,shift @have);
      push @out,$lh,$x,$rh;

    } else {

      my $y=shift @have;

      push @out,$x;
      push @out,'+',$y if($y);

    };

  };


  return @out;


};

# ---   *   ---   *   ---
# get value from descriptor

sub operand_value($self,$type,@data) {


  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};

  my $rtab  = $self->register;


  # walk operands
  map {

    if($ARG->{type} eq 'r') {
      my $reg=$rtab->{$ARG->{reg}};
      $reg->{$type->{name}};

    } elsif(! index $ARG->{type},'m') {


      my @have = addr_collapse $ARG->{imm_args};
      my @r    = ();

      if($ARG->{type} eq 'mlea') {

        @r=map {
          $rtab->{$ARG-1}->{dword}

        } grep {$ARG} (
          $ARG->{rX},
          $ARG->{rY},

        );


      } elsif($ARG->{type} eq 'msum') {
        @r=$rtab->{$ARG->{reg}}->{dword};

      } elsif($ARG->{type} eq 'mstk') {
        @r=$rtab->{$anima->stack_base}->{dword};

      };


      push @r,join '',@have;
      my $out=join '+',@r;


      $out .= '*'. (1 << $ARG->{scale})
      if $ARG->{scale};

      "$type->{name} [$out]";


    } elsif(exists $ARG->{id}) {
      symname $ARG,'id';

    } else {
      $ARG->{imm};

    };


  } @data;

};

# ---   *   ---   *   ---
# ~

sub is_label {

  my $data=$_[0]->{data};
  return (is_coderef $data)
    ? 'cpos' eq codename $data
    : 0
    ;

};

# ---   *   ---   *   ---
# ~

sub step($self,$data) {


  my $main = $self->{main};
  my $eng  = $main->{engine};
  my $mc   = $main->{mc};

  my ($seg,$route,@req)=@$data;

  map {

    my ($type,$ins,@args)=@$ARG;
    $type=typefet $type;

  if(! ($ins=~ $self->metains)) {

    $ins=$self->instab->{$ins}
    if exists $self->instab->{$ins};


    if($ins eq 'data-decl') {


      my @path = @{$args[0]->{id}};
      my $name = shift @path;

      my $full = join '_',@path,$name;


      if(is_label $args[0]) {
        "\n$full:";

      } else {

        my ($dd)   = $self->data_decl($type);
        my ($data) = $eng->value_flatten(
          $args[0]->{data}->{value}

        );


        my $sym=${$mc->valid_psearch(
          $name,@path

        )};


        my $str  = Type->is_str($sym->{type});
        my $cstr = $sym->{type} eq typefet 'cstr';


        my $sus=2;
        if(is_arrayref $data) {

          $sus  *= int @$data;
          $data  = ($str)
            ? join ",",map {"\"$ARG\""} @$data
            : join ",",@$data
            ;

        } else {
          $data="\"$data\""  if $str;

        };


        $data="$data,\$00" if $cstr;


        my $out=
          "$full:\n"
        . "  $dd $data\n"
        ;

        $out .=

          "\n$full.len="

        . ((length $data)-($sus+$cstr*3))

        . "\n"

        if $str;

        $out;

      };

    } else {
      my @have=$self->operand_value($type,@args);
      sprintf "  %-16s %s",$ins,join ',',@have;

    };


  }} @req;

};

# ---   *   ---   *   ---
1; # ret
