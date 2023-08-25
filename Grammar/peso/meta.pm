#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO META
# Data bout other data
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::meta;

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
  use Grammar::peso::std;
  use Grammar::peso::ops;

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw($PE_META);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $PE_META=>
    'Grammar::peso::meta';

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_value();
  $PE_STD->use_eye();

  # class attrs
  fvars('Grammar::peso::common');

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[info-key]  => re_pekey(qw(version author)),

    q[xlate-key] => re_pekey(qw(xlate)),
    q[lib-key]   => re_pekey(qw(lib use)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('$<header> sigil opt-nterm term');

  rule('~<info-key>');
  rule('$<info> info-key nterm term');


  rule('~<xlate-key>');
  rule('~<lib-key>');

  rule('$<xlate> &_xlate xlate-key nterm term');
  rule('$<lib> lib-key nterm term');

# ---   *   ---   *   ---
# post-parse file header

sub header($self,$branch) {

  state $tab={
    '$' => 'exec',
    '%' => 'rom',

  };


  # ensure header is first statement
  ! $self->{p3}->{leaves}->[0]
  or throw_header();


  # unpack
  my ($sigil,$lang)=
    $self->rd_name_nterm($branch);


  # ^repack
  $branch->{value}={

    mode => $tab->{$sigil},
    lang => $lang,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^errme

sub throw_header($self) {

  errout(

    q[Peso header must be first ]
  . q[statement in file],

    lvl=>$AR_FATAL,

  );

};

# ---   *   ---   *   ---
# ^bind

sub header_ctx($self,$branch) {

  my $st    = $branch->{value};

  my $mode  = $st->{mode};
  my $lang  = $st->{lang};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};


  # make value ice
  $mode=$mach->vice('str',raw=>$mode);
  $lang=$mach->vice('str',raw=>$lang);

  # reset path
  $scope->path('meta');


  # ^add ids and bind
  $mode->{id}='src-mode';
  $lang->{id}='src-lang';

  $mode->bind($scope);
  $lang->bind($scope);


  # retire node
  $branch->discard();

};

# ---   *   ---   *   ---
# post-parse file data

sub info($self,$branch) {

  my ($type,$data)=
    $self->rd_name_nterm($branch);


  $type=lc $type;


  $branch->clear();
  $branch->{value}={
    type => $type,
    data => $data->[0],

  };

};

# ---   *   ---   *   ---
# ^bind

sub info_ctx($self,$branch) {

  my $st   = $branch->{value};
  my $mach = $self->{mach};

  my $type = $st->{type};
  my $data = $st->{data};
  my @path = 'meta';


  $data->{id}=$type;
  $mach->bind($data,path=>\@path);

  $branch->discard();

};

# ---   *   ---   *   ---
# post-parse translation
# data for emitter

sub _xlate($self,$branch) {

  state $tab={

    fasm => 'asm',

    c    => 'c',
    cpp  => 'cpp',

    perl => 'pl',
    peso => 'pe',

    non  => $NULLSTR,

  };


  my ($key,$lang,$ext)=
    $self->rd_name_nterm($branch);


  # validate language name
  $lang=lc $lang->[0]->get();

  throw_lang($lang)
  if ! exists $tab->{$lang};


  # ^get extension
  $ext//=[];
  $ext=(! $ext->[0])
    ? $tab->{$lang}
    : $ext->[0]->get()
    ;


  # repack
  $branch->{value}={
    lang => $lang,
    ext  => $ext,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^errme

sub throw_lang($name) {

  errcaller();

  errout(
    q[Unrecognized language '%s' ]
  . q[passed to [ctl]:%s],

    lvl  => $AR_FATAL,
    args => [$name,'XLATE'],

  );

};

# ---   *   ---   *   ---
# ^does a path change to
# affect subsequent directives

sub _xlate_ctx($self,$branch) {

  my $st    = $branch->{value};

  my $lang  = $st->{lang};
  my $ext   = $st->{ext};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my @path  = ($lang ne 'non')
    ? (qw(meta xlate),$lang)
    : ()
    ;

  # set path and save value
  $scope->path(@path);
  $mach->decl(bare=>'ext',raw=>$ext)
  if @path;

  # retire node
  $branch->discard();

};

# ---   *   ---   *   ---
# post-parse includes

sub lib($self,$branch) {

  my ($type,$nterm)=$branch->leafless_values();

  $branch->{value}={
    type => lc $type,
    data => $nterm,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^binds

sub lib_ctx($self,$branch) {

  my $st   = $branch->{value};

  my $type = $st->{type};
  my $data = $st->{data};

  # ^get ctx
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $dst   = undef;
  my @path  = $scope->path();

  # ^reset path if current scope is invalid
  if(! @path || $path[0] ne 'meta') {
    @path=$scope->path('meta');

  };


  # ^add entry to scope
  if(! $scope->haslv($type)) {
    $dst=$mach->decl(stk=>$type,raw=>[]);

  # ^get existing
  } else {
    $dst=$scope->getvar($type,as_ptr=>1);

  };


  # ^save data and retire node
  push @{$$dst->{raw}},$data;
  $branch->discard();

};

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  my $s=(Tree::Grammar->is_valid($branch))
    ? $branch->to_string()
    : $branch
    ;


  $O{skip}=1;
  my $ice=$class->parse($s,%O);


  return $ice->{sremain};

};

# ---   *   ---   *   ---
# make a parser tree

  our @CORE=qw(lcom header info xlate lib);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
