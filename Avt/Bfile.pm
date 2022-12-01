#!/usr/bin/perl
# ---   *   ---   *   ---
# BFILE
# Intermediate stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::Bfile;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Readonly;

  use Exporter 'import';

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::IO;

  use Shb7;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Lang;
  use Lang::C;
  use Lang::Perl;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  our @EXPORT=qw(

    $AVTOPATH

  );

# ---   *   ---   *   ---
# ROM

  Readonly our $AVTOPATH=
    q[-I].$ENV{'ARPATH'}.'/avtomat/';

# ---   *   ---   *   ---
# constructor

sub nit($class,$fpath,%O) {

  my $self=bless {

    src=>$fpath,

    obj=>Shb7::obj_from_src(
      $fpath,
      ext=>$O{obj_ext}

    ),

    dep=>Shb7::obj_from_src(
      $fpath,
      ext=>$O{dep_ext}

    ),

    asm=>Shb7::obj_from_src(
      $fpath,
      ext=>$O{asm_ext}

    ),

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# give 1 if object was rebuilt

sub update($self) {

  my $out=0;

  if($self->needs_update()) {
    $out=$self->build();

  };

  return $out;

};

# ---   *   ---   *   ---
# give 1 if object needs to be rebuilt

sub needs_update($self) {

  my $out=0;

  if($self->{src}=~ $Lang->Perl->{ext}) {
    $out=$self->pl_updated();

  } else {
    $out=$self->c_updated();

  };

  return $out;

};

# ---   *   ---   *   ---
# C-style rebuild check

sub c_updated($self) {

  my $do_build = !(-f $self->{obj});
  my @deps     = @{$self->c_get_deps()};

  # no missing deps
  $self->depchk(\@deps);

  # make sure we need to update
  $self->buildchk(\$do_build,\@deps);

  return $do_build;

};

# ---   *   ---   *   ---
# Perl-style rebuild check

sub pl_updated($self) {

  state $is_mam=qr{MAM\.pm$};

  my $do_build=
     !(-f $self->{obj})
  || Shb7::ot($self->{obj},$self->{src})
  ;

  if($self->{src}=~ $is_mam) {
    $do_build=0;
    goto TAIL;

  };

  my @deps=@{$self->pl_get_deps()};

  # no missing deps
  $self->depchk(\@deps);

  # make sure we need to update
  $self->buildchk(\$do_build,\@deps);

  # depsmake hash needs to know
  # if this one requires attention
  if(!(-f $self->{dep}) || $do_build) {
    Shb7::push_makedeps(
      $self->{obj},$self->{dep}

    );

  };

TAIL:
  return $do_build;

};

# ---   *   ---   *   ---
# give 1 if *.o file was produced

sub build($self) {

  my $out=0;

  if($self->{src}=~ $Lang->Perl->{ext}) {
    $out=$self->pl_build();

  } else {
    $out=$self->c_build();

  };

  return $out;

};

# ---   *   ---   *   ---
# C-style object file boiler

sub c_build($self) {

  say {*STDERR} Shb7::shpath($src);

  my $asm=$self->{obj};
  $asm=~ s[$Lang::C::EXT_OB][.asm];

  my $up=$NULLSTR;
  if($self->{src}=~ $Lang::C::EXT_PP) {
    $up='-lstdc++';

  };

  my @call=(

    q[gcc],

    q[-m64],

    @{$Shb7::OFLG},
    Shb7::get_includes(),

    $up,



    q[-c],$self->{src},
    q[-o],$self->{obj}

  );

  array_filter(\@call);
  system {$call[0]} @call;

  return -f $self->{obj};

};

# ---   *   ---   *   ---
# Perl "building"
#
# actually it's applying any
# custom source filters

sub pl_build($self) {

  print {*STDERR} Shb7::shpath($src)."\n";

  my @call=(
    q[perl],q[-c]

    q[-I].$AVTOPATH.q[/hacks/],
    q[-I].$AVTOPATH.q[/Peso/],
    q[-I].$AVTOPATH.q[/Lang/],

    q[-I].Shb7::dir($Shb7::Cur_Module),
    Shb7::get_includes(),

    q[-MMAM=--rap,].
    q[--module=].$Shb7::Cur_Module,

    $src

  );

  my $ex  = join q[ ],@call;
  my $out = `$ex 2> $AVTOPATH/.errlog`;

  if(!length $out) {
    my $log=orc("$AVTOPATH/.errlog");
    say {*STDERR} $log;

  };

  for my $fname(
    $self->{obj},
    $self->{dep}

  ) {

    if(!(-f $fname)) {
      my $path=dirof($fname);
      `mkdir -p $path`;

    };

  };

  owc($self->{obj},$out);

  return 0;

};

# ---   *   ---   *   ---
# check object date against dependencies

sub buildchk($do_build,$deps) {

  if(!$$do_build) {
    while(@$deps) {

      my $dep=shift @$deps;
      if(!(-f $dep)) {next};

      # found dep is updated
      if(Shb7::ot($self->{obj},$dep)) {
        $$do_build=1;
        last;

      };

    };

  };

};

# ---   *   ---   *   ---
# sanity check: dependency files exist

sub static_depchk($self,$deps) {

  for my $dep(@$deps) {

    if($dep && !(-f $dep)) {

      errout(

        "%s missing dependency %s\n",

        args=>[
          Shb7::shpath($self->{src}),
          $dep

        ],

        lvl=>$AR_FATAL,

      );

    };

  };

};

# ---   *   ---   *   ---
# gives dependency file list from str

sub get_deps($self,$depstr) {

  # make list
  my $out=[Lang::ws_split(
    $COMMA_RE,$depstr

  )];

  # ensure there are no blanks
  array_filter($out);

  return $out;

};

# ---   *   ---   *   ---
# makes file list out of gcc .d files

sub c_get_deps($self) {

  my $out=[$self->{src}];

  if(!(-f $self->{dep})) {
    goto TAIL

  };

  # read file
  my $body=orc($self->{dep});

  # sanitize
  $body=~ s/\\//g;
  $body=~ s/\s/\,/g;
  $body=~ s/.*\://;

  # make
  $out=$self->get_deps($body);

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# makes file list out of pcc .pmd files

sub pl_get_deps($self) {

  my $out=[];

  if(!(-f $self->{dep})) {
    goto TAIL

  };

  # read
  my $body  = orc($self->{dep});
  my $fname = $NULLSTR;
  my @slurp;

  # assign
  my ($fname,$body,@slurp)=
    split $NEWLINE_RE,$body;

  # skip if blank
  if(!defined $fname || !defined $body) {
    goto TAIL

  };

  # make
  $out=$self->get_deps($body);

TAIL:
  return $out;

};

# ---   *   ---   *   ---
1; # ret
