#!/usr/bin/perl
# ---   *   ---   *   ---
# BLOCK
# Makes perl reps of peso objects
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::block;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/include/';
  my %PESO=do 'peso/defs.ph';

# ---   *   ---   *   ---

  use constant {

    # permissions
    O_RD=>0b001,
    O_WR=>0b010,
    O_EX=>0b100,

    # just for convenience
    O_RDWR=>0b011,
    O_RDEX=>0b101,
    O_WREX=>0b110,

    O_RDWREX=>0b111,

  };

# ---   *   ---   *   ---

my %CACHE=(

  -WED=>undef,

);



# ---   *   ---   *   ---

sub nit {

  my $self=shift;
  my $name=shift;
  my $size=shift;
  my $attrs=shift;

  if(!defined $size) {
    $size=$PESO{-SIZES}->{'line'};

  };if(!defined $attrs) {
    $attrs=0b000;

  };

  my $blk=bless {

    -NAME=>$name,
    -SIZE=>$size,

    -PAR=>$self,

    -ELEMS=>{},
    -DATA=>[],

    -ATTRS=>$attrs,

  },'peso::block';

  if($self) {
    $self->elems->{$name}=$blk;

  };

  return $blk;

};

# ---   *   ---   *   ---

# getters
sub name {return (shift)->{-NAME};};
sub elems {return (shift)->{-ELEMS};};
sub par {return (shift)->{-PAR};};
sub data {return (shift)->{-DATA};};
sub size {return (shift)->{-SIZE};};
sub attrs {return (shift)->{-ATTRS};};

# ---   *   ---   *   ---

sub wedcast {

  my $shf=shift;

  my $elem_sz=$PESO{-SIZES}
    ->{$CACHE{-WED}};

  my $i=$shf/8;

  my $gran=(1<<($elem_sz*8))-1;
  return $gran<<$shf;

};

# ---   *   ---   *   ---

# in: array of [key,value] references,
# in: data type

# inserts new elements into block

sub expand {

  my $self=shift;

  my $ref=shift;
  my $type=shift;

  $CACHE{-WED}=$type;

  my $elem_sz=$PESO{-SIZES}->{$type};
  $self->{-SIZE}+=@$ref*$elem_sz;

  my $line_sz=$PESO{-SIZES}->{'line'};
  my $gran=(1<<($elem_sz*8))-1;

# ---   *   ---   *   ---

  my $i=0;my $j=@{$self->data};
  push @{$self->data},0x00;

  while(@$ref) {

    my $ar=shift @$ref;

    my $k=$ar->[0];
    my $v=$ar->[1];

    my $shf=$i*8;
    my $mask=$gran<<$shf;

    $v=$v<<$shf;

    $self->elems->{$k}=[$j,$shf,$mask];
    $self->data->[$j]|=$v;

    $i+=$elem_sz;
    if($i>=($line_sz/2)) {

      push @{ $self->data },0x00;
      $j++;$i=0;

    };

  };

};

# ---   *   ---   *   ---

# in: name,value
# sets value at offset
sub setv {

  my $self=shift;

  if(!($self->attrs& O_WR)) {
    printf "block '".$self->name.
      "' cannot be written\n";

    exit;

  };

  my $name=shift;
  my $value=shift;

  my $cast=shift;

  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  if(defined $cast) {
    $CACHE{-WED}=$cast;

  };if(defined $CACHE{-WED}) {
    $mask=wedcast($shf);

  };

  $value=$value&($mask>>$shf);
  $self->data->[$idex]&=~$mask;
  $self->data->[$idex]|=$value<<$shf;

};

# ---   *   ---   *   ---

# in: name to fetch
# returns stored value
sub getv {

  my $self=shift;
  my $name=shift;

  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  my $value=$self->data->[$idex];
  $value&=$mask;

  return $value>>$shf;

};

# ---   *   ---   *   ---

# in: name to fetch
# returns byte offsets assoc with name

sub getloc {

  my $self=shift;
  my $name=shift;

  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  return ($idex,$shf/8);

};

# ---   *   ---   *   ---+

sub prich {

  my $self=shift;
  my $v_lines='';

# ---   *   ---   *   ---

  # get values
  { my $i=0;
    for my $v(reverse @{$self->data}) {
      $v_lines.=sprintf "%.16X ",$v;
      if($i) {$v_lines.="\n";$i=0;};

      $i++;

    };
  };

# ---   *   ---   *   ---

  # get names and offsets
  my $n_lines='              ';

  { my %h=%{$self->elems};
    my @ar=();

    for my $k(keys %h) {
      my ($idex,$off)=$self->getloc($k);
      @ar[$idex*8+$off]=$k;

    };

    $n_lines=join ',',reverse @ar;

  };

printf $n_lines."\n  0x".$v_lines."\n";

};

# ---   *   ---   *   ---
1; # ret
