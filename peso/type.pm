#!/usr/bin/perl
# ---   *   ---   *   ---
# TYPE
# So you can redefine primitives
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::type;

  use v5.36.0;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# getters

sub size($self) {return $self->{size}};
sub fields($self) {return $self->{fields}};

# ---   *   ---   *   ---

;;sub is_primitive($self) {
  return exists $self->fields->{'primitive'};

};sub elem_count($self) {
  return $self->{elem_count};

};

# ---   *   ---   *   ---
# constructors

sub new_frame(@args) {
  return peso::type::frame::create(@args);

};sub nit($frame,$name,$elems) {

  my $size=0;
  my $count=0;

  my $fields={};

# ---   *   ---   *   ---
# struct format:
#
#   > 'type_name'=>[
#
#   >   ['type_name','elem_name']
#   >   ...
#
#   >  ];

  if(length ref $elems) {

    for my $elem(@$elems) {

      my $elem_type=$elem->[0];
      my $elem_name=$elem->[1];

      $fields->{$elem_name}=$elem_type;
      $size+=$frame->{$elem_type}->size;

      $count++;

    };

# ---   *   ---   *   ---
# primitive format:
#
#   > 'type_name'=>size

  } else {

    $count=1;
    $size=$elems;

    $fields->{'primitive'}=$name;

  };

# ---   *   ---   *   ---

  my $type=$frame->{$name}=bless {

    size=>$size,
    elem_count=>$count,

    fields=>$fields,

  },'peso::type';

  return $type;

};

# ---   *   ---   *   ---

package peso::type::frame;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# constructors

sub nit(@args) {return peso::type::nit(@args)};

sub create() {

  my $frame=bless {

  },'peso::type::frame';

  return $frame;

};

# ---   *   ---   *   ---
1; # ret
