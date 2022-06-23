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
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---
# getters

sub size($) {return (shift)->{-SIZE};};
sub fields($) {return (shift)->{-FIELDS};};

# ---   *   ---   *   ---

;;sub is_prim($) {
  return exists ((shift)->fields->{'primitive'});

};sub elem_count($) {
  return (shift)->{-ELEM_COUNT};

};

# ---   *   ---   *   ---
# constructors

sub new_frame() {
  return peso::type::frame::create();

};sub nit($$$) {

  my ($frame,$name,$elems)=@_;

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

    -SIZE=>$size,
    -ELEM_COUNT=>$count,

    -FIELDS=>$fields,

  },'peso::type';

  return $type;

};

# ---   *   ---   *   ---

package peso::type::frame;
  use strict;
  use warnings;

# ---   *   ---   *   ---
# constructors

sub nit($$$) {
  my ($frame,$name,$elems)=@_;
  return peso::type::nit($frame,$name,$elems);

};sub create() {

  my $frame=bless {

  },'peso::type::frame';

  return $frame;

};

# ---   *   ---   *   ---
1; # ret
