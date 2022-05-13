#!/usr/bin/perl
# ---   *   ---   *   ---
# PLUTS
# Utilities for making OO
# Perl modules
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package pluts;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/avtomat/';

# ---   *   ---   *   ---
# flags/shorthands/convenience

  use constant {

    ATTR_MAN=>0x00,

    ATTR_GET=>0x01,
    ATTR_SET=>0x02,
    ATTR_EXE=>0x04,

# ---   *   ---   *   ---

    ARGCHK=>q(

my $value=shift;
if( !($:condition;>($value)) ) {

  print

    "Value '$value' is invalid ".
    "for attr '$:attr_name;>' ".
    "of class <".$:cls_name;>.">\n";

  exit;

};return 1;

    ),

  };

# ---   *   ---   *   ---
# utils for method generation

my %GENERATORS

=(-GETSET=>q(

  my $self=shift;
  my $value=shift;

  if(defined $value) {
    $:argchk;>($value);
    $self->{$:key;>}=$value;

  };return $self->{$:key;>};

),-GET=>q(

  return (shift)->{$:key;>};

),-SET=>q(

  my $self=shift;
  my $value=shift;

  $:argchk;>($value);
  $self->{$:key;>}=$value;

),-EXE=>q( return (shift)->{%s}->() ),

);

# ---   *   ---   *   ---
# in: { key:[value,condition] }
# ensures values are set at nits
# rejects invalid overwrites

sub DEFAULTS {

  my $h=shift;
  my $cls_name=caller;
  $cls_name="\"$cls_name\"";

  my @methods=('','');

# ---   *   ---   *   ---
# we accumulate to this code-string

  $methods[0]=q/

sub new {

  my %kwargs=@_;
  my %h=(
/;

# ---   *   ---   *   ---
# iter through attrs

  for my $key(keys %$h) {
    my ($value,$condition,$flags)=@{$h->{$key}};

# ---   *   ---   *   ---
# errchk the coderef

    my $coderef=eval('\&'.$condition);
    $coderef=int(defined &$coderef);

    if(!$coderef) {

# ---   *   ---   *   ---
# throw invalid

      if($condition) {

        printf

          "'condition' field for attr ".
          "'$key' is invalid; accepted values are ".

          "zero, undef or coderef\n\n";

        exit;

# ---   *   ---   *   ---
# no condition

      } else {$condition='sub {return 1;}->'};
    };

# ---   *   ---   *   ---
# generate methods for attr

    my $attr_name=lc(
      substr $key,1,(length $key)-1

    );

    my $vchk_name="__${attr_name}_argchk";
    my $argchk=ARGCHK;

    $argchk="sub $vchk_name {\n".$argchk."\n};\n";

    $argchk=~ s/\$:condition;>/${condition}/sg;
    $argchk=~ s/\$:attr_name;>/${attr_name}/sg;
    $argchk=~ s/\$:cls_name;>/${cls_name}/sg;

    push @methods,$argchk;

# ---   *   ---   *   ---
# switch($flags)

    if($flags) {

      my $method="sub $attr_name {";

      # read-write
      if(!($flags ^ (ATTR_GET|ATTR_SET)) ) {
        $method.=$GENERATORS{-GETSET};

      # read only
      } elsif($flags & ATTR_GET) {
        $method.=$GENERATORS{-GET};

      # write only
      } elsif($flags & ATTR_SET) {
        $method.=$GENERATORS{-SET};


      # method rets a sub call
      } elsif($flags & ATTR_EXE) {
        $method.=$GENERATORS{-EXE};

      };

# ---   *   ---   *   ---
# replace tags in generator

      $method=~ s/\$:argchk;>/${vchk_name}/sg;
      $method=~ s/\$:condition;>/${condition}/sg;
      $method=~ s/\$:key;>/${key}/sg;

      $method.="};\n";
      push @methods,$method;

# ---   *   ---   *   ---
# accumulate attrs to the nit
# then replace the tags

    };$methods[0].=q/

    $:key;>=>(

       exists $kwargs{$:attr_name;>}
    && $:argchk;>($kwargs{$:attr_name;>})

    ) ? $kwargs{$:attr_name;>}
      : $:value;>,

/;$methods[0]=~ s/\$:attr_name;>/${attr_name}/sg;
  $methods[0]=~ s/\$:key;>/${key}/sg;
  $methods[0]=~ s/\$:value;>/${value}/sg;
  $methods[0]=~ s/\$:argchk;>/${vchk_name}/sg;

  };$methods[0].=q/
  );return bless \%h,$:cls_name;>;

};
/;

# ---   *   ---   *   ---
# put it all together

  $methods[0]=~ s/\$:cls_name;>/${cls_name}/sg;
  return ''.(join "\n",@methods);

};

# ---   *   ---   *   ---
1; # ret

