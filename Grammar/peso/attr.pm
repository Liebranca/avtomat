#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO ATTR
# Flags of a block
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::attr;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

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
  fvars('Grammar::peso::file');


  # attr defaults
  Readonly my $PE_ATTR=>{

    static=>0,
    inline=>0,

  };

  # ^list of switches
  Readonly my $PE_ATTR_T=>{

    static   => [qw(static 1)],
    dynamic  => [qw(static 0)],

    inline   => [qw(inline 1)],
    called   => [qw(inline 0)],

  };

# ---   *   ---   *   ---
# GBL

  our $REGEX={
    q[attr-key] => re_pekey(qw(attr)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<attr-key>');
  rule('$<attr> attr-key nterm term');

# ---   *   ---   *   ---
# ^post-parse file select

sub attr($self,$branch) {

  my ($type,$flags)=
    $self->rd_name_nterm($branch);

  $type=lc $type;
  $flags//=[];


  $branch->{value}={
    type  => $type,
    flags => $flags,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind

sub attr_ctx($self,$branch) {

  my $st    = $branch->{value};
  my $flags = $st->{flags};

  $flags=[map {
    $self->deref($ARG,key=>1)->get()

  } @$flags];


  # get current hier
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $par   = $scope->curblk();
  my $pst   = $par->{value};


  # set defaults if need
  map {

    $pst->{attr}->{$ARG}=
      $PE_ATTR->{$ARG};

  } keys %$PE_ATTR if ! %{$pst->{attr}};


  # ^modify
  my $dst=$pst->{attr};

  map {

    my ($key,$value)=
      @{$PE_ATTR_T->{$ARG}};

    $dst->{$key}=$value;

  } @$flags;


  $branch->discard();

};

# ---   *   ---   *   ---
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
