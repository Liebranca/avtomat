#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO CMWC
# cpy,mov,wap,clr
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::cmwc;

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

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_value();
  $PE_STD->use_eye();

  fvars('Grammar::peso::var');

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[cmwc-key]=>re_pekey(qw(
      cpy mov wap clr

    )),

  };



# ---   *   ---   *   ---
# parser rules

  rule('~<cmwc-key>');
  rule('$<cmwc> cmwc-key nterm term');

# ---   *   ---   *   ---
# ^post parse

sub cmwc($self,$branch) {

  state $arg_cnt={

    cpy => 2,
    mov => 2,
    wap => 2,

    clr => 1,

  };

  # unpack
  my ($type,$vars)=
    $self->rd_name_nterm($branch);


  $type=lc $type;


  # errchk args
  throw_cmwc($type)
  if @$vars > $arg_cnt->{$type};


  # ^repack
  $branch->{value}={
    type => $type,
    vars => $vars,

  };


  $branch->clear();

};

# ---   *   ---   *   ---
# ^errme

sub throw_cmwc($type) {

  errout(

    q[Too many args for ]
  . q[instruction [ctl]:%s],

    lvl  => $AR_FATAL,
    args => [$type],

  );

};

# ---   *   ---   *   ---
# determines if register/stack
# space required by op

sub cmwc_ctx($self,$branch) {

  my $st   = $branch->{value};

  my $type = $st->{type};
  my $vars = $st->{vars};

  return if $type eq 'clr';


  # get current block
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $blk   = $scope->curblk();


  # ^register vars if need
  map {
    $self->hier_stktab_set($blk,$ARG)

  } @$vars;

};

# ---   *   ---   *   ---
# ^execute

sub cmwc_run($self,$branch) {

  my $st   = $branch->{value};

  my $type = $st->{type};
  my $vars = $st->{vars};

  my ($a,$b)=map {
    $self->deref($ARG,key=>1);

  } @$vars;


  # copy B into A
  if($type eq 'cpy') {
    $a->set($b);

  # ^clear B after copy
  } elsif($type eq 'mov') {
    $a->set($b);
    $b->set($NULL);

  # ^swap B with A
  } elsif($type eq 'wap') {

    my $tmp=$a->get();

    $a->set($b);
    $b->set($tmp);

  # ^clear A
  } else {
    $a->set(0);

  };

};

# ---   *   ---   *   ---
# out fasm codestr

sub cmwc_fasm_xlate($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};
  my $x86   = $mach->{x86_64};
  my $blk   = $scope->curblk();

  my $type  = $st->{type};
  my $vars  = $st->{vars};

  my @out   = ();


  # copy A to B
  if($type eq 'cpy') {

    my @args=();
    my @prev=();

    map {

      my ($a,@b)=
        $ARG->fasm_xlate($self);

      push @args,$a;
      push @prev,@b;

    } reverse @$vars;

    push @out,@prev,"  mov " . (
      join q[,],reverse @args

    );

  };


  $branch->{fasm_xlate}=join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# out perl codestr

sub cmwc_perl_xlate($self,$branch) {

  my $st    = $branch->{value};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $type  = $st->{type};
  my $vars  = $st->{vars};

  my $out   = $NULLSTR;

  if($type eq 'clr') {

    my $var = $vars->[0];
    my $id  = "\$$var->{id}";

    my $raw = $var->get();

    if(is_hashref($raw)) {
      $raw={};

    } elsif(is_arrayref($raw)) {
      $raw=[];

    } elsif($var->{type} eq 'num') {
      $raw=0;

    } elsif($var->{type} eq 'str') {
      $raw=$NULLSTR;

    } else {
      $raw=$NULL;

    };

    $out="$id=$raw;";

  } else {

    my ($a,$b)=@$vars;

    my ($dst)=(! $a->{id})
      ? $a->perl_xlate(id=>0,scope=>$scope)
      : $a->perl_xlate(value=>0,scope=>$scope)
      ;

    my ($value)=$b->perl_xlate(
      id=>0,scope=>$scope

    );


    if($type eq 'cpy') {
      $out="$dst=$value;";

    } elsif($type eq 'mov') {
      $out="$dst=$value;$value=undef;";

    } else {
      $out="($dst,$value)=($value,$dst);";

    };

  };

  $branch->{perl_xlate}=$out;

};

# ---   *   ---   *   ---
# do not generate a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
