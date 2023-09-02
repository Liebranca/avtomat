#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO CDEF
# Compile-time defines
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::cdef;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::re;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.2;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_eye();

  # class attrs
  fvars('Grammar::peso::common');

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[cdef-key]=>re_pekey(qw(
      def undef redef

    )),

    q[cdef-name]=>qr{\@[^;\s\#]+}x,

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<cdef-key>');
  rule('~<cdef-name>');

  rule('$<cdef> cdef-key cdef-name nterm term');

# ---   *   ---   *   ---
# ^post-parse

sub cdef($self,$branch) {

  # unpack
  my ($type,$name,$value)=
    $branch->leafless_values();

  $type  = lc $type;
  $value = join

  $branch->{value}={

    type  => $type,

    name  => $name,
    value => $value,

  };

  $branch->clear();
  $self->cdef_run($branch);

};

# ---   *   ---   *   ---
# handle cdef type

sub cdef_run($self,$branch) {

  my $st    = $branch->{value};

  my $type  = $st->{type};
  my $name  = $st->{name};
  my $value = $st->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  # make new
  if($type eq 'def') {
    $scope->cdef_decl($value,$name);

  # ^reset existing
  } elsif($type eq 'redef') {
    $scope->cdef_asg($value,$name);

  # ^remove
  } else {
    $scope->cdef_rm($name);

  };

  $scope->cdef_recache();

};

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  my $s=(Tree::Grammar->is_valid($branch))
    ? $branch->{value}
    : $branch
    ;

  my $ice   = $class->parse($s,%O,skip=>1);

  my $mach  = $ice->{mach};
  my $scope = $mach->{scope};

  # ^apply
  my $vref=\$ice->{sremain};
  while($scope->value_crepl($vref)) {};

  # ^clear macros
  $scope->cdef_clear();


  return $ice->{sremain};

};

# ---   *   ---   *   ---
# make parser tree

  our @CORE=qw(cdef);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
