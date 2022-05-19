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
  use avt;

# ---   *   ---   *   ---
# flags/shorthands/convenience

  use constant {

    ATTR_MAN=>0x00,

    ATTR_GET=>0x01,
    ATTR_SET=>0x02,

    ATTR_CCH=>0x04,

    ATTR_EXE=>0x08,

# ---   *   ---   *   ---

    ARGCHK=>q(

### VALUE CHECK
  my $value=shift;
  if( !($:condition;>($value)) ) {

    print

      "Value '$value' is invalid ".
      "for attr '$:attr_name;>' ".
      "of class <".$:cls_name;>.">\n";

    exit;

  };return 1;
### VALUE CHECK

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

),-EXE=>q(

  return (shift)->{$:key;>}->()

# ---   *   ---   *   ---

),-CACHE_GETSET=>q(

  my $value=shift;

  if(defined $value) {
    $:argchk;>($value);
    $:argchk;>->{$:key;>}=$value;

  };return $$:cache;>->{$:key;>};

),-CACHE_GET=>q(

  return $$:cache;>->{$:key;>};

),-CACHE_SET=>q(

  my $value=shift;

  $:argchk;>($value);
  $$:cache;>->{$:key;>}=$value;

),-CACHE_EXE=>q(

  return $$:cache;>->{$:key;>}->();

),

);

# ---   *   ---   *   ---
# in: { key:[value,condition] }
# ensures values are set at nits
# rejects invalid overwrites

sub MODULE($$) {

  my $deps=shift;
  my $attrs=shift;

  my $cls_name=caller;
  my $cache_name=(uc $cls_name).'_CACHE';

  my @methods=('','');

# ---   *   ---   *   ---

  $methods[1]=q/

my $$:cache;>={};sub CACHE {
  return $$:cache;>;

};
/;$methods[1]=~ s/\$:cache;>/$cache_name/sg;

# ---   *   ---   *   ---
# make the deps block

  my $hed=avt::note(caller->AUTHOR,'#');

  $hed.="\n# deps\npackage $cls_name;";
  $hed.=q(
  use strict;
  use warnings;

);for my $path(keys %$deps) {

    $hed.="  use lib $path;\n";
    for my $lib(@{$deps->{$path}}) {
      $hed.="  use $lib;\n";

    };
  };

# ---   *   ---   *   ---
# we accumulate attrs to this code-string

  $cls_name="\"$cls_name\"";
  $methods[0]=q/

sub new {

  my %kwargs=@_;
  my %h=(
/;

# ---   *   ---   *   ---
# iter through attrs

  for my $key(keys %$attrs) {
    my ($value,$condition,$flags)=@{$attrs->{$key}};

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

    my $is_cache_op=$flags & ATTR_CCH;
    if($flags) {

      my $method="sub $attr_name(\$:proto;>) {";
      my $proto='';

      my @gens=(-GETSET,-GET,-SET,-EXE);

      if($is_cache_op) {
      for my $gen(@gens) {
        $gen=~ s/-/-CACHE_/;

      };} else {
        $proto='$';

      };

      $flags&=~ ATTR_CCH;

      # read-write
      if(!($flags ^ (ATTR_GET|ATTR_SET)) ) {
        $proto.=';$';
        $method.=$GENERATORS{$gens[0]};

      # read only
      } elsif($flags & ATTR_GET) {
        $method.=$GENERATORS{$gens[1]};

      # write only
      } elsif($flags & ATTR_SET) {
        $proto.='$';
        $method.=$GENERATORS{$gens[2]};


      # method rets a sub call
      } elsif($flags & ATTR_EXE) {
        $method.=$GENERATORS{$gens[3]};

      };

# ---   *   ---   *   ---
# replace tags in generator

      $method=~ s/\$:argchk;>/${vchk_name}/sg;
      $method=~ s/\$:condition;>/${condition}/sg;
      $method=~ s/\$:key;>/${key}/sg;

      $method=~ s/\$:proto;>/${proto}/sg;
      $method=~ s/\$:cache;>/${cache_name}/sg;

      $method.="};\n";
      push @methods,$method;

# ---   *   ---   *   ---
# accumulate attrs to the nit
# then replace the tags

    };if(!$is_cache_op) {$methods[0].=q/

    $:key;>=>(

       exists $kwargs{$:attr_name;>}
    && $:argchk;>($kwargs{$:attr_name;>})

    ) ? $kwargs{$:attr_name;>}
      : $:value;>,

/;$methods[0]=~ s/\$:attr_name;>/${attr_name}/sg;
  $methods[0]=~ s/\$:key;>/${key}/sg;
  $methods[0]=~ s/\$:value;>/${value}/sg;
  $methods[0]=~ s/\$:argchk;>/${vchk_name}/sg;

  } else {$methods[1].=q/

if(!exists CACHE->{$:key;>}) {
  CACHE->{$:key;>}=$:value;>;

};

/;$methods[1]=~ s/\$:key;>/${key}/sg;
  $methods[1]=~ s/\$:value;>/${value}/sg;

# ---   *   ---   *   ---

  }};$methods[0].=q/
  );return bless \%h,$:cls_name;>;

};
/;

  # put it all together
  $methods[0]=~ s/\$:cls_name;>/${cls_name}/sg;
  my $body=''.(join "\n",@methods);

# ---   *   ---   *   ---

  return $hed."\n".$body."\n1;\n";

};

# ---   *   ---   *   ---
1; # ret

