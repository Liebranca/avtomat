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

  use xlate::fasm_opt;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
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

  haveopt => {
    mul => 1,
    mod => \&xlate::fasm_opt::expand_mod,
    div => 1,

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


  # recurse on structure?
  if(@{$type->{struc_t}}) {

    return map {

      my $field = typefet $type->{struc_t}->[$ARG];

      my $cnt   = $type->{layout}->[$ARG];
      my $label = $type->{struc_i}->[$ARG];


      [ $label => (
        $class->data_decl_key($field)

      ) x $cnt];

    } 0..@{$type->{struc_t}}-1;


  # plain value!
  } else {

    return map {@{{

      byte  => [('db') x 1],
      word  => [('dw') x 1],
      dword => [('dd') x 1],
      qword => [('dq') x 1],

      xword => [('dq') x 2],
      yword => [('dq') x 4],
      zword => [('dq') x 8],

    }->{$ARG}}} typeof $type->{sizeof};

  };

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$main) {
  return bless {main=>$main},$class;

};

# ---   *   ---   *   ---
# get symbol name

sub symname($self,$src,$key='id') {

  my $mem  = $self->{main}->{mc}->{bk}->{mem};

  my @path = @{$src->{$key}};
  my $name = shift @path;

  return join '_',grep {
    ! ($ARG=~ $mem->anon_re)

  } @path,$name;

};

# ---   *   ---   *   ---
# decompose memory operand

sub addr_collapse($self,$tree) {

  my $opera = qr{^(?:\*|\/)$};
  my @have  = map {

    my $neg = 0;
    my @out = ();

    # have fetch?
    if(exists $ARG->{imm}) {
      @out = $self->symname($ARG,'id');
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


      my @r    = ();
      my @have = $self->addr_collapse(
        $ARG->{imm_args}

      );

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
      $self->symname($ARG,'id');

    } else {
      $ARG->{imm};

    };


  } @data;

};

# ---   *   ---   *   ---
# handle label decls!

sub is_label {

  my $data=$_[0]->{data};
  return (is_coderef $data)
    ? 'cpos' eq codename $data
    : 0
    ;

};

# ---   *   ---   *   ---
# walk instruction block

sub step($self,$data) {

  my ($seg,$route,@req)=@$data;

  map {

    my ($type,$ins,@args)=@$ARG;
    $type=typefet $type;


  # only process non-meta instructions!
  if(! ($ins=~ $self->metains)) {

    $ins=$self->instab->{$ins}
    if exists $self->instab->{$ins};


    # writing raw bytes?
    if($ins eq 'data-decl') {
      map {$self->data_decl($type,$ARG)} @args;

    # making segment?
    } elsif($ins eq 'seg-decl') {
      $self->seg_decl(@args);


    # expandable instruction?
    } elsif(exists $self->haveopt->{$ins}) {

      my $fn=$self->haveopt->{$ins};

      map {$self->insout(@$ARG)}
      $fn->($self,$type,$ins,@args);


    # straight op!
    } else {
      $self->insout($type,$ins,@args);

    };


  }} @req;

};

# ---   *   ---   *   ---
# format single instruction

sub insout($self,$type,$ins,@args) {

  my @have=$self->operand_value($type,@args);

  return (@have)

    ? sprintf "  %-16s %s",
      $ins,join ',',@have

    : "  $ins"

    ;

};

# ---   *   ---   *   ---
# paste file header ;>

sub open_boiler($self) {


  # get ctx
  my $main  = $self->{main};
  my $fmode = $main->{fmode};
  my $mem   = $main->{mc}->{bk}->{mem};

  my @out   = ();
  my @entry = (defined $main->{entry})
    ? grep {
        ! $ARG=~ $mem->anon_re

    } @{$main->{entry}} : () ;


  # outputting straight static
  if($fmode == 1) {

    $main->perr(
      'no entry point for <%s>',
      args=>[$main->{fpath}],

    ) if ! @entry;

    push @out,"format ELF64 executable 3";
    push @out,'entry '.join '_',@entry;


  # outputting object
  } else {


    # just convert entry to a public symbol
    # if it was declared, that is!
    push @out,"format ELF64";
    push @out,'public '.join '_',@entry
    if @entry;

  };

  return @out,null;

};

# ---   *   ---   *   ---
# messy string handler

sub bytestr($cstr,@data) {


  # join by comma...
  join ",",map {

    (! is_arrayref $ARG)
      ? "'$ARG->[0]'" : $ARG->[0] ;

  # ^all strings found...
  } grep {
    length $ARG


  # ^within the input data!
  } map {

    my @chars=split null,$ARG;
    my @subst=('');


    # handle special chars
    map {

      my $c=ord($ARG);
      if($c < 0x20 || $c > 0x7E) {
        push @subst,[$c];
        push @subst,'';

      } else {
        $subst[-1] .= $ARG;

      };


    } @chars;


    # add nullterm?
    ($cstr)
      ? (@subst,[0x00])
      : (@subst)
      ;


  } @data;

};

# ---   *   ---   *   ---
# add labels for non-anonymous

sub data_decl_label($self,$key,$have_t,$data,%O) {


  # defaults
  $O{str}  //= 0;
  $O{cstr} //= 0;


  # handle string conversions
  my $have   = shift @$data;
     $have //= 0;

  $have=join ',',map {

    ($O{str})
      ? bytestr $O{cstr},$ARG
      : $ARG
      ;

  } (is_arrayref $have) ? @$have : $have ;


  # paste string and length?
  my $out="  $have_t $have";

  if(! ($key=~ qr{_L\d+$})) {
    $out  = "\n$key:\n$out\n";
    $out .= "\nsizeof.$key=\$-$key\n";

  };

  return $out;

};

# ---   *   ---   *   ---
# handle data declaration block

sub data_decl($self,$type,$src) {


  # get ctx
  my $main = $self->{main};
  my $eng  = $main->{engine};
  my $mc   = $main->{mc};
  my $mem  = $mc->{bk}->{mem};


  # unpack
  my @path = @{$src->{id}};
  my $name = shift @path;

  # get [fullname => symbol]
  my $full = join '_',grep {
    ! ($ARG=~ $mem->anon_re)

  } @path,$name;

  my $sym  = ${$mc->valid_psearch(
    $name,@path

  )};


  # have label?
  if(is_label $src) {

    # need to declare symbol for export?
    return ($sym->{public} && $main->{fmode} != 1)
      ? ("\npublic $full","$full:")
      : "\n$full:"
      ;


  # have value!
  } else {


    my (@dd)   = $self->data_decl_key($type);
    my ($data) = $eng->value_flatten(
      $src->{data}->{value}

    );


    my $sym=${$mc->valid_psearch(
      $name,@path

    )};


    my $str  = Type->is_str($sym->{type});
    my $cstr = $sym->{type} eq typefet 'cstr';

    my @name = ($full);
    my @decl = ();
    my @data = (is_arrayref $data)
      ? @$data : $data ;

    while(@dd) {


      # get next label/type
      my $key    = shift @name;
      my $have_t = shift @dd;

      # have type sequence?
      if(is_arrayref $have_t) {

        my ($label,@field)=@$have_t;


        # solo array?
        if($label eq '?') {

          my @have=@data[0..$#field];
             @data=@data[@field..$#data];


          push @decl,$self->data_decl_label(

            $key => $field[0],[\@have],

            str  => $str,
            cstr => $cstr,

          );


        # struc?
        } else {

          push    @decl,"$key:";
          unshift @dd,@field;

          push    @name,($#field > 0)

            ? map {sprintf "$key.label\@%04X",$ARG}
              0..$#field

            : "$key.label"

            ;

        };


        next;


      # single value!
      } else {

        push @decl,$self->data_decl_label(

          $key => $have_t,\@data,

          str  => $str,
          cstr => $cstr,

        );

      };

    };


    return @decl;

  };

};

# ---   *   ---   *   ---
# handle segment declaration

sub seg_decl($self,@args) {

  # get ctx
  my $main  = $self->{main};
  my $mc    = $main->{mc};
  my $mem   = $mc->{bk}->{mem};
  my $fmode = $main->{fmode};

  # get input
  my @path  = @{$args[0]->{id}};
  my $name  = shift @path;

  my $full  = join '_',@path,$name;


  # building executable?
  if($fmode == 1) {

    my $attrs = {

      rom => 'readable',
      ram => 'readable writeable',
      exe => 'readable executable',

    }->{$args[0]->{data}};

    return join "\n",(

      "\nsegment $attrs",
      "align 16\n",

      (! ($name=~ $mem->anon_re))
        ? "$full:"
        : ()
        ,

    );


  # building object!
  } else {

    my $attrs = {

      rom => '.rodata',
      ram => '.data',
      exe => '.text',

    }->{$args[0]->{data}};


    return join "\n",(

      "\nsection '$attrs' align 16",

      (! ($name=~ $mem->anon_re))
        ? "$full:"
        : ()
        ,

    );

  };

};

# ---   *   ---   *   ---
1; # ret
