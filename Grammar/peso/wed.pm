#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO WED
# Flagged for spam
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::wed;

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

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::re;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_WED);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_eye();

  # class attrs
  fvars('Grammar::peso::common');

  # cat [flag=>default] lists
  Readonly my $PE_FLAGS=>{
    %{$PE_RE_FLAGS},

  };

  Readonly our $PE_WED=>
    'Grammar::peso::wed';

# ---   *   ---   *   ---
# GBL

  our $REGEX={
    q[wed-key]=>re_pekey(qw(wed unwed)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<wed-key>');
  rule('$<wed> wed-key nterm term');

# ---   *   ---   *   ---
# ^post-parse

sub wed($self,$branch) {

  # unpack
  my ($type,@flags)=
    $self->rd_name_nterm($branch);

  $type=lc $type;


  # ^repack
  $branch->{value}={

    type  => $type,

    flags => [map {@$ARG} @flags],
    ptr   => [],

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind

sub wed_ctx($self,$branch) {

  my $st    = $branch->{value};

  my $type  = $st->{type};
  my $flags = $st->{flags};
  my $ptr   = $st->{ptr};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $value = $type eq 'wed';


  # retrieve ptr to lexical
  # then set/unset var
  map {
    push @$ptr,$scope->getvar($ARG->get());
    $ptr->[-1]->set($value);

  } @$flags;

};

# ---   *   ---   *   ---
# ^step-over

sub wed_walk($self,$branch) {

  my $st    = $branch->{value};

  my $type  = $st->{type};
  my $ptr   = $st->{ptr};

  my $value = $type eq 'wed';

  map {$ARG->set($value)} @$ptr;

};

sub wed_run($self,$branch) {
  $self->wed_walk($branch);

};

# ---   *   ---   *   ---
# get default values

sub flags_default($class) {

  $class=(length ref $class)
    ? ref $class
    : $class
    ;

  no strict 'refs';
  my $flags=${"$class\::PE_FLAGS"};

  return $flags;

};

# ---   *   ---   *   ---
# ^retrieve current

sub flags_get($self) {

  my $mach  = $self->{mach};
  my $scope = $self->{scope};

  my $flags = $self->flags_default();


  return { map {
    $ARG=>$scope->getvar($ARG)->get()

  } keys %$flags };

};

# ---   *   ---   *   ---
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
