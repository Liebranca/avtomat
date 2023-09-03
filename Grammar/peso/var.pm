#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO VAR
# Boxes that hold things
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::var;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_value();
  $PE_STD->use_eye();
  $PE_STD->use_hier();

  # class attrs
  fvars([
    'Grammar::peso::common',
    'Grammar::peso::hier',

  ]);

# ---   *   ---   *   ---
# GBL

  our $REGEX={

    q[lis-key] => re_pekey(qw(lis)),

    width=>re_pekey(qw(

      byte wide brad word
      unit half line page

      nihil stark signal

    )),

    spec=>re_pekey(qw(
      ptr fptr str buf tab

    )),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<width>');
  rule('~<spec>');
  rule('*<specs> &list_flatten spec');

  rule('$<type> width specs');

  rule('$<ptr-decl> &ptr_decl type nterm term');

  rule(q[
    $<blk-ice>
    &blk_ice

    value value opt-nterm term

  ]);

  rule('~<lis-key>');
  rule('$<lis> lis-key value value term');

# ---   *   ---   *   ---
# ^post-parse

sub ptr_decl($self,$branch) {

  # signal that this is a decl
  # to subtrees when recursing
  my $f=$self->{frame};
  push @{$f->{-cdecl}},1;

  my $lv   = $branch->{leaves};
  my $type = $lv->[0];


  # ^unpack specs
  my $type_lv = $type->{leaves};
  my $width   = $type_lv->[0]->leaf_value(0);

  my @spec    = (defined $type_lv->[1])
    ? $type_lv->[1]->branch_values()
    : ()
    ;

  @spec  = map {lc $ARG} @spec;
  $width = lc $width;


  # parse nterm
  my ($names,$values)=$self->rd_nterm(
    $lv->[1]->{leaves}->[0],

  );

  # ^unpack values
  my @names=map {

    ($ARG->{type} eq 'array_decl')
      ? @{$ARG->get()}
      : $ARG->get()
      ;

  } @$names;


  # ^repack ;>
  $branch->{value}={

    width  => $width,
    spec   => \@spec,

    names  => \@names,
    values => $values,

    ptr    => [],

  };


  # terminate declaration
  $branch->clear();
  pop @{$f->{-cdecl}};

};

# ---   *   ---   *   ---
# ^pre-run step

sub ptr_decl_ctx($self,$branch) {

  return if ! $branch->{value};


  my $mach   = $self->{mach};
  my @path   = $mach->{scope}->path();

  my $st     = $branch->{value};
  my $f      = $self->{frame};

  my @names  = @{$st->{names}};

  # errchk
  throw_invalid_scope(\@names,@path)
  if !$f->{-crom}
  && !$f->{-creg}
  && !$f->{-cproc}
  ;

  # select default cstruc
  my $dtype=(defined $st->{spec}->[-1])
    ? $st->{spec}->[-1]
    : 'void'
    ;

  # ^enforce on uninitialized
  $mach->defnull($dtype,\$st->{values},@names);

  # bind and save ptrs
  $self->bind_decls($st);

};

# ---   *   ---   *   ---
# ^errme

sub throw_invalid_scope($names,@path) {

  my $p=(@path) ? join q[/],@path : $NULLSTR;
  my $s=join q[,],@$names;

  errout(

    q[No valid container for ]
  . q[decls [errtag]:%s at ]
  . q[[goodtag]:%s],

    args => [$s,$p],
    lvl  => $AR_FATAL,

  );

};

# ---   *   ---   *   ---
# register decls to current scope

sub bind_decls($self,$st) {

  my $width  = $st->{width};
  my $names  = $st->{names};
  my $values = $st->{values};
  my $ptr    = $st->{ptr};

  my $mach   = $self->{mach};
  my $rom    = $self->inside_ROM();


  # iter
  map {

    my $name  = $names->[$ARG];
    my $value = $values->[$ARG];

    # set ctx attrs
    $value->{id}    = $name;
    $value->{width} = $width;
    $value->{const} = $rom;

    # write to mem
    push @$ptr,$mach->bind($value);

  } 0..@$names-1;

  return $ptr;

};

# ---   *   ---   *   ---
# post-parse for block instances

sub blk_ice($self,$branch) {

  # signal that this is a decl
  # to subtrees when recursing
  my $f=$self->{frame};
  push @{$f->{-cdecl}},1;


  # get leaves
  my $lv    = $branch->{leaves};

  my $blk   = $lv->[0]->leaf_value(0);
  my $name  = $lv->[1]->leaf_value(0);
  my $nterm = $lv->[2]->{leaves}->[0];

  # parse nterm
  my ($args)=($nterm)
    ? $self->rd_nterm($nterm)
    : []
    ;

  $args //= [];


  # ^repack ;>
  $branch->{value}={

    blk  => $blk->get(),

    name => $name->get(),
    args => $args,

    in   => [],
    out  => [],

    ptr  => [],

  };


  # terminate declaration
  $branch->clear();
  pop @{$f->{-cdecl}};

};

# ---   *   ---   *   ---
# ^get in/out fmat for blk

sub blk_ice_ctx($self,$branch,@keys) {

  return if ! $branch->{value};


  my $st   = $branch->{value};
     @keys = qw(in out) if ! @keys;


  map {

    $st->{$ARG}=
      $self->blk_ice_io($branch,$ARG);

    $self->blk_ice_bind($branch,$ARG);

  } @keys;

};

# ---   *   ---   *   ---
# ^process IO branch in scope

sub blk_ice_io($self,$branch,$key) {

  my $out   = [];
  my $st    = $branch->{value};

  my $name  = $st->{name};
  my $blk   = $st->{blk};

  my $mach  = $self->{mach};
  my $scope = $mach->{scope};


  # get IO branch
  my @path = $scope->search_nc($blk);
  my $io   = $scope->haslv(@path,$key);


  # ^proc found
  goto SKIP if ! $io;

  $out=[ map {(

    "$name.$ARG->{value}"=>
      $ARG->leaf_value(0)

  )} @{$io->{leaves}} ];


SKIP:
  return $out;

};

# ---   *   ---   *   ---
# ^binds IO vars for field

sub blk_ice_bind($self,$branch,$key) {

  my $st     = $branch->{value};

  my $ptr    = $st->{ptr};
  my $args   = $st->{args};


  # get field
  my @names  = array_keys($st->{$key});
  my @values = array_values($st->{$key});


  # apply new defaults if avail
  map {
    $values[$ARG]=$args->[$ARG];

  } 0..@$args-1;

  @values=grep {$ARG} @values;


  # ^bind values as new decls
  push @$ptr,map {

    my $name  = $names[$ARG];
    my $value = $values[$ARG]->dup();

    $value->{scope}=undef;

    my $o={

      width  => $value->{width},

      names  => [$name],
      values => [$value],

      ptr    => [],

    };

    @{$self->bind_decls($o)};

  } 0..$#values;

};

# ---   *   ---   *   ---
# post-parse for aliasing

sub lis($self,$branch) {

  my $lv    = $branch->{leaves};

  my ($type,$name,$value)=
    $branch->leafless_values();


  $type=lc $type;


  $branch->{value}={

    type => $type,

    to   => $name,
    from => $value,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^context build

sub lis_ctx($self,$branch) {

  my $st    = $branch->{value};
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $key   = $st->{to};
     $key   = $key->get();

  my @path  = $scope->path();

  $mach->lis(

    $key => $st->{from},
    path => \@path,
  );

};

# ---   *   ---   *   ---
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
