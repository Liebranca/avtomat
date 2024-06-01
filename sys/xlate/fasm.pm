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

  our $VERSION = v0.00.2;#a
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

    int   => 'syscall',

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

sub data_decl_key($class,$type) {

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
      map {$self->data_decl($type,$ARG)} @args;

    } elsif($ins eq 'seg-decl') {

      my $full  = symname $args[0],'id';
      my $fmode = $main->{fmode};

      if($fmode == 1) {

        my $attrs = {

          rom => 'readable',
          ram => 'readable writeable',
          exe => 'readable executable',

        }->{$args[0]->{data}};

        join "\n",(

          "\nsegment $attrs",
          "align 16\n",

          "$full:"

        );

      } else {

        my $name = {

          rom => '.rodata',
          ram => '.data',
          exe => '.text',

        }->{$args[0]->{data}};

        join "\n",(
          "\nsection '$name' align 16",
          "$full:"

        );

      };


    } else {

      my @have=$self->operand_value($type,@args);

      (@have)

        ? sprintf "  %-16s %s",
          $ins,join ',',@have

        : "  $ins"

        ;

    };


  }} @req;

};

# ---   *   ---   *   ---
# ~

sub open_boiler($self) {


  # get ctx
  my $main  = $self->{main};
  my $fmode = $main->{fmode};
  my $entry = $main->{entry};

  my @out   = ();


  # ~
  if($fmode == 1) {

    $main->perr(
      'no entry point for <%s>',
      args=>[$main->{fpath}],

    ) if ! @$entry;

    push @out,"format ELF64 executable 3";
    push @out,'entry '.join '_',@$entry;

  } else {
    push @out,"format ELF64";

    push @out,'public '.join '_',@$entry
    if @$entry

  };

  return @out,null;

};

# ---   *   ---   *   ---
# ~

sub bytestr($cstr,@data) {

  join ",",map {

    (! is_arrayref $ARG)
      ? "'$ARG'" : $ARG->[0]

  } grep {
    length $ARG

  } map {

    my @chars=split null,$ARG;
    my @subst=('');

    map {

      my $c=ord($ARG);
      if($c < 0x20 || $c > 0x7E) {
        push @subst,[$c];
        push @subst,'';

      } else {
        $subst[-1] .= $ARG;

      };


    } @chars;


    ($cstr)
      ? (@subst,[0x00])
      : (@subst)
      ;


  } @data;

};

# ---   *   ---   *   ---
# handle data declaration block

sub data_decl($self,$type,$src) {


  # get ctx
  my $main = $self->{main};
  my $eng  = $main->{engine};
  my $mc   = $main->{mc};


  # unpack
  my @path = @{$src->{id}};
  my $name = shift @path;

  my $full = join '_',@path,$name;


  if(is_label $src) {
    return "\n$full:";

  } else {


    my ($dd)   = $self->data_decl_key($type);
    my ($data) = $eng->value_flatten(
      $src->{data}->{value}

    );


    my $sym=${$mc->valid_psearch(
      $name,@path

    )};


    my $str  = Type->is_str($sym->{type});
    my $cstr = $sym->{type} eq typefet 'cstr';


    my $sus=2;
    if(is_arrayref $data) {

      $sus  *= int @$data;

      if($str) {
        $data=bytestr $cstr,@$data;

      } else {
        $data=join ",",@$data;

      };

    } else {
      $data=bytestr $cstr,$data if $str;

    };


    my $out="  $dd $data";


    # add labels for non-anonymous!
    if(! ($full=~ qr{_L\d+$})) {

      $out  = "\n$full:\n$out\n";
      $out .=

        "\n$full.len="

      . ((length $data)-($sus+$cstr*3))

      . "\n"

      if $str;

    };


    return $out;

  };

};

# ---   *   ---   *   ---
1; # ret
