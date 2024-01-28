#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO IO
# Forms of communication
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::io;

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

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_value();
  $PE_STD->use_eye();
  $PE_STD->use_var();

  # class attrs
  fvars('Grammar::peso::var');

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[io-key]=>re_pekey(qw(io in out)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<io-key>');
  rule('|<io-value> &clip ptr-decl blk-ice');
  rule('$<io> &io io-key io-value');

# ---   *   ---   *   ---
# ^post-parse

sub io($self,$branch) {

  my @lv    = @{$branch->{leaves}};
  my $class = $self->{frame}->{-class};

  my $st={
    type  => lc $lv[0]->leaf_value(0),
    value => $lv[1],

  };

  $branch->{value}='io';
  $branch->clear_nproc();

  $branch->inew($st);

};

# ---   *   ---   *   ---
# ^get all inputs in scope

sub io_ctx($self,$branch) {

  return if ! @{$branch->{leaves}};

  my $st=$self->io_merge($branch);

  # get current path
  my $f     = $self->{frame};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my @path  = $scope->path();

  # ^discard blk if present
  pop @path if $f->{-cblk};


  # ^register values
  map {

    my $key=$ARG;
    $scope->path(@path,$key) if $key ne 'io';

    # bind values
    map {

      $ARG->{value}->{io}=1;


      # copy in/out fmat from F
      if($key eq 'io') {

        $scope->path(@path,'in');
        $self->blk_ice_ctx($ARG,'in');

        $scope->path(@path,'out');
        $self->blk_ice_ctx($ARG,'out');


      # ^plain ptr, copy either
      } else {

        my $fn=codename($ARG->{pfn});

        if(begswith($fn,'blk_ice')) {
          $self->$fn($ARG,$key);
          $self->blk_ice_cl($ARG,$key);

        } else {
          $self->$fn($ARG);

        };

      };


      my $ptr=$ARG->{value}->{ptr};

      $ARG->{value}=0;
      $ARG->discard();

      $ARG=$ptr;

    } @{$st->{$key}};


    # ^flatten ptr lists
    @{$st->{$key}}=map {
      @$ARG

    } @{$st->{$key}};


  } qw(in out io);


  # add entries to parent
  my $blk=$scope->get_branch(@path);
  my $bst=$blk->{value};

  map {
    $bst->{$ARG}=$st->{$ARG};

  } qw(in out);


  # restore previous path
  push @path,$f->{-cblk} if $f->{-cblk};
  $scope->path(@path);

};

# ---   *   ---   *   ---
# ^combines io nodes

sub io_merge($self,$branch) {

  state $re=qr{^io$};

  # get all IO branches
  my $par = $branch->{parent};
  my @lv  = $par->branches_in($re);


  # ^merge values
  my @st  = map {$ARG->leaf_value(-1)} @lv;
  my $out = {in=>[],out=>[],io=>[]};

  map {
    my $dst=$out->{$ARG->{type}};
    push @$dst,$ARG->{value};

  } @st;

  # ^set
  $branch->{value}=$out;


  # ^pluck all but first
  map {
    $ARG->clear();
    $ARG->discard();

  } grep {$ARG ne $branch} @lv;

  $branch->clear();


  return $out;

};

# ---   *   ---   *   ---
# crux

sub recurse($class,$branch,%O) {

  my $s=(Tree::Grammar->is_valid($branch))
    ? $branch->{value}
    : $branch
    ;


  my $ice=$class->parse($s,%O,skip=>1);

  return $ice->{sremain};

};

# ---   *   ---   *   ---
# make a parser tree

  our @CORE=qw(io);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
