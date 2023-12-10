#!/usr/bin/perl
# ---   *   ---   *   ---
# BK MAM
# Wrappers for Perl "builds"
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Bk::mam;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Path;
  use Arstd::IO;

  use Arstd::WLog;

  use Shb7;
  use Shb7::Path;
  use Shb7::Bfile;

  use parent 'Shb7::Bk';

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang::Perl;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# add entry to build files

sub push_src($self,$fpath,$fout) {

  push @{$self->{files}},

  Shb7::Bfile->nit(

    $fpath,
    $self,

    out     => $fout,

    obj_ext => q[.pm],
    dep_ext => q[.pmd],
    asm_ext => undef,

  );

  return $self->{files}->[-1];

};

# ---   *   ---   *   ---
# Perl-style rebuild check

sub fupdated($self,$bfile) {

  state $is_mam=qr{MAM\.pm$};


  my $do_build=
     (! -f $bfile->{obj})
  || Shb7::ot($bfile->{obj},$bfile->{src})
  ;

  if($bfile->{src}=~ $is_mam) {
    $do_build=0;
    goto TAIL;

  };

  my @deps=$self->fdeps($bfile);

  # no missing deps
  $bfile->depchk(\@deps);

  # make sure we need to update
  $bfile->buildchk(\$do_build,\@deps);

  # depsmake hash needs to know
  # if this one requires attention
  if((! -f $bfile->{dep}) || $do_build) {

    Shb7::push_makedeps(
      $bfile->{obj},$bfile->{dep}

    );

  };

TAIL:
  return $do_build;

};

# ---   *   ---   *   ---
# makes file list out of pcc .pmd files

sub fdeps($self,$bfile) {

  my @out=();

  if(! -f $bfile->{dep}) {
    goto TAIL

  };

  # read
  my $body  = orc($bfile->{dep});
  my $fname = $NULLSTR;

  # assign
  ($fname,$body)=split $NEWLINE_RE,$body;

  # skip if blank
  if(!$fname || !$body) {
    goto TAIL

  };

  # make
  @out=$self->depstr_to_array($body);

TAIL:
  return @out;

};

# ---   *   ---   *   ---
# shorthand for this big ole bashit

sub mamcall($self,$bfile,$bld,$rap=1) {

  my @libpaths=grep {
    $ARG=~ $LIBD_RE

  } @{$bld->{libs}};


  map {$ARG=~ s[$LIBD_RE][-I]} @libpaths;

  $rap=($rap)
    ? q[--rap,]
    : $NULLSTR
    ;

  my @call=(
    q[perl],q[-c],

    q[-I].$AVTOPATH.q[/hacks/],
    q[-I].$AVTOPATH.q[/Peso/],
    q[-I].$AVTOPATH.q[/Lang/],

    q[-I].Shb7::dir($Shb7::Path::Cur_Module),

    @{$bld->{incl}},
    @libpaths,

    q[-MMAM=].$rap.
    q[--module=].$Shb7::Path::Cur_Module,

    $bfile->{src}

  );

  return @call;

};

# ---   *   ---   *   ---
# Perl "building"
#
# actually it's applying any
# custom source filters

sub fbuild($self,$bfile,$bld,$rap=1) {

  $WLog->substep(
    Shb7::shpath($bfile->{src})

  ) if $rap;

  my @call = $self->mamcall($bfile,$bld,$rap);

  my $ex   = join q[ ],@call;
  my $out  = `$ex 2> $AVTOPATH/.errlog`;

  if(! length $out) {

    my $log=orc("$AVTOPATH/.errlog");

    $WLog->err(

      'failed to apply filters',

      from    => 'MAM',
      details => $log,

      lvl     => $AR_FATAL,

    );

  };

  for my $fname(
    $bfile->{obj},
    $bfile->{dep}

  ) {

    if(! -f $fname) {
      my $path=dirof($fname);
      `mkdir -p $path`;

    };

  };

  owc($bfile->{obj},$out);

  if($rap) {

    $bfile->{src}=$bfile->{obj};
    $bfile->{obj}=$bfile->{out};

    $self->fbuild($bfile,$bld,0);

  };

  return 0;

};

# ---   *   ---   *   ---
1; # ret
