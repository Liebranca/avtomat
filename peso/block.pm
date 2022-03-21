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

sub nit {

  my $self=shift;
  my $name=shift;
  my $size=shift;

  my $blk=bless {

    -NAME=>$name,
    -SIZE=>$size,

    -PAR=>$self,

    -ELEMS=>{},
    -DATA=>[],

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

# ---   *   ---   *   ---

# in: array of [key,value] references,
# in: data type

# inserts new elements into block

sub expand {

  my $self=shift;

  my $ref=shift;
  my $type=shift;

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
  my $name=shift;
  my $value=shift;

  my $cast=shift;

  my ($idex,$shf,$mask)=@{
    $self->elems->{$name}

  };

  if(defined $cast) {
    my $elem_sz=$PESO{-SIZES}->{$cast};
    my $i=$shf/8;

    my $gran=(1<<($elem_sz*8))-1;
    $mask=$gran<<$shf;

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
