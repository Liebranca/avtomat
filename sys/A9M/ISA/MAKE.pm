#!/usr/bin/perl
# ---   *   ---   *   ---
# A9M ISA:MAKE
# Puts opcode tables together!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package A9M::ISA::MAKE;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_words);
  use List::Util qw(max);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

  use Arstd::Array;
  use Arstd::Bytes;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# fetch or make mnemonic id

sub get_idx($class,$cache,$name,%O) {


  # get ctx
  my $key = $cache->{mnemonic};
  my $tab = $cache->{exetab};


  # ^register new?
  if(! exists $key->{$O{fn}}) {

    push @$tab,$O{fn};

    $key->{$O{fn}}={
      name => $name,
      idx  => $cache->{execode}++,

    };

  };


  # give id
  return $key->{$O{fn}}->{idx};

};

# ---   *   ---   *   ---
# get possible operand sizes

sub get_operand_size($class,$bld,%O) {

  my @size=(! $O{nosize})
    ? qw(byte word dword qword)
    : $bld->{ins_def_t}->{name}
    ;

  @size=(@{$O{fix_size}})
  if defined $O{fix_size};


  return @size;

};

# ---   *   ---   *   ---
# get possible operand combinations

sub get_operand_type($class,%O) {

  my @type=();

  # two-operand instruction
  if($O{argcnt} eq 2) {

    @type=grep {length $ARG} map {

      my $dst   = substr $ARG,0,1;
      my $src   = substr $ARG,2,1;

      my $allow =
         (0 <= index $O{dst},$dst)
      && (0 <= index $O{src},$src)
      ;

      $ARG if $allow;

    } 'r_r','r_m','r_i','m_r','m_i';


  # ^single operand, so no combo ;>
  } elsif($O{argcnt} eq 1) {
    @type=split $NULLSTR,$O{dst};

  };


  return @type;


};

# ---   *   ---   *   ---
# ^generate further variations

sub expand_operand_type($class,$type,%O) {


  # we need 2 iterations for this ;>
  for my $round(0..1) {

    @$type=map {

      my $cpy  = $ARG;
      my @list = ();


      # have memory operand?
      if($round == 0) {
        @list=(qr{m},qw(mstk mimm msum mlea));

      } else {

        my @ar=($O{fix_immsrc})
          ? 'i'.(qw(x y)[$O{fix_immsrc}-1])
          : qw(ix iy)
          ;

        @list=(qr{i(?!mm)},@ar);

      };


      # ^need to generate specs?
      if(@list) {

        # replace plain combo with
        # specific variations!

        my ($re,@repl)=@list;

        map {

          my $cpy2=$cpy;

          $cpy2=~ s[$re][$ARG];
          $cpy2;

        } @repl;


      # ^nope, use plain combo
      } else {
        $ARG;

      };


    } @$type;

  };


  # remove duplicates and give
  array_dupop($type);
  return;

};

# ---   *   ---   *   ---
# output no-operand instruction

sub gen_no_operand($class,$bld) {


  # get ctx
  my $name   = $bld->{name};
  my $icetab = $bld->{meta}->{icetab};
  my $cache  = $bld->{cache};


  # contents of entry
  my $data={

    %{$bld->{ROM}},

    argflag => 0x00,
    opsize  => 0x00,
    idx     => $bld->{idx},

  };

  # ^save idex
  $icetab->{$name}=$cache->{romcode};


  # give table entry
  return $name => {
    id  => $cache->{romcode}++,
    ROM => $data,

  };

};

# ---   *   ---   *   ---
# ^output variation on instruction
# with one or more operands

sub gen_have_operand($class,$bld) {


  # get ctx
  my $tab  = $bld->{operand_tid};
  my $type = $bld->{type};
  my $name = $bld->{name};


  # unpack operand type combination
  my ($dst,$src)=split '_',$bld->{type};
  $src //= $NULLSTR;


  # ^map to binary
  my $operands =
    ($tab->{"d$dst"})
  | ($tab->{"s$src"});


  # gen variation of instruction name
  my $ins   = "${name}_$type";
  my @sizeb = @{$bld->{sizear}};

  if($src eq 'iy' || $dst eq 'iy') {
    @sizeb=grep {$ARG ne 'byte'} @sizeb;

  };


  # ^give sized variants
  map {

    $bld->{operands} = $operands;
    $bld->{insname}  = "${ins}_${ARG}";
    $bld->{size}     = $ARG;

    $class->gen_sized_ins($bld);

  } @sizeb;

};

# ---   *   ---   *   ---
# ^make sized variations

sub gen_sized_ins($class,$bld) {


  # get ctx
  my $meta  = $bld->{meta};
  my $cache = $bld->{cache};
  my $name  = $bld->{insname};
  my $size  = typefet $bld->{size};


  # make entry contents
  my $data={

    %{$bld->{ROM}},

    operands => $bld->{operands},

    opsize   => $size->{sizep2},
    idx      => $bld->{idx},

  };



  # perl-side copy
  $meta->{icetab}->{$bld->{insname}}=
    $cache->{romcode};

  # give entry
  $name => {
    id  => $cache->{romcode}++,
    ROM => $data,

  };

};

# ---   *   ---   *   ---
# cstruc instruction(s)

sub gen_opcode($class,$bld,$name,%O) {


  # defaults
  $O{fn}          //= $name;
  $O{argcnt}      //= 2;
  $O{nosize}      //= 0;

  $O{load_src}    //= int($O{argcnt} == 2);
  $O{load_dst}    //= 1;

  $O{fix_immsrc}  //= 0;
  $O{fix_regsrc}  //= 0;
  $O{fix_size}    //= undef;

  $O{overwrite}   //= 1;
  $O{dst}         //= 'rm';
  $O{src}         //= 'rmi';


  # save for internal use
  my $cache=$bld->{cache};

  $cache->{insmeta}->{$name}=\%O;
  $bld->{name}=$name;


  # ^for writing/instancing
  $bld->{ROM}={

    load_src    => $O{load_src},
    load_dst    => $O{load_dst},
    overwrite   => $O{overwrite},

    argcnt      => $O{argcnt},

  };

  # ^just for the compiler
  $bld->{meta}=$cache->{insmeta}->{$name};
  $bld->{meta}->{icetab}={};


  # queue logic generation
  $bld->{idx}=$class->get_idx($cache,$name,%O);


  # get operand sizes and types
  my @size=$class->get_operand_size($bld,%O);
  my @type=$class->get_operand_type(%O);

  # ^no operands!
  return $class->gen_no_operand($bld)
  if ! @type;


  # else get real ;>
  $class->expand_operand_type(\@type,%O);


  # make argument type variations
  $bld->{sizear}=\@size;

  return map {

    $bld->{type}=$ARG;
    $class->gen_have_operand($bld);

  } @type;

};

# ---   *   ---   *   ---
# entry point

sub crux($class,$dst,$bldfn) {


  # fetch instruction table
  my $bld    = $bldfn->();
  my $guts_t = $bld->{guts_t};
  my $tab    = $guts_t->table;

  $bld->{cache} = $dst;


  # ^array as hash
  my $ti = 0;
  my @tk = array_keys($tab);
  my @tv = array_values($tab);


  # ^walk
  $dst->{romtab} = [ map {
    $class->gen_opcode($bld,$ARG,%{$tv[$ti++]})

  } @tk ];


  # ^save bitsizes and give
  $dst->{id_bs}  = bitsize $dst->{romcode};
  $dst->{idx_bs} = bitsize $dst->{execode};
  $dst->{id_bm}  = bitmask $dst->{id_bs};
  $dst->{idx_bm} = bitmask $dst->{idx_bs};


  return $dst;

};

# ---   *   ---   *   ---
1; # ret
