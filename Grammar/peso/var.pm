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

  use Arstd::Int;
  use Arstd::Array;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#b
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

  $self->decl_prologue($branch);

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

    io     => 0,

    width  => $width,
    spec   => \@spec,

    names  => \@names,
    values => $values,

    ptr    => [],

  };

  $branch->clear();
  $self->decl_epilogue($branch);

};

# ---   *   ---   *   ---
# ^open boiler

sub decl_prologue($self,$branch) {


  # signal that this is a decl
  # to subtrees when recursing
  my $f=$self->{frame};
  push @{$f->{-cdecl}},1;

};

# ---   *   ---   *   ---
# ^close boiler

sub decl_epilogue($self,$branch) {

  # terminate declaration
  my $f=$self->{frame};
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
  $self->alias_decl($branch) if ! $st->{io};

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

  $self->bind_decl_ptrs($st);

  return $ptr;

};

# ---   *   ---   *   ---
# ^further step

sub bind_decl_ptrs($self,$st) {


  # get ctx
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  # get mode
  my @path = $scope->path();
  my $key  = 'stk';

  if($st->{io}) {
    my @cpy=@path;
    $key=pop @cpy;

    $scope->path(@cpy);

  };


  # get hier
  my $blk=$scope->curblk();
  my $bst=$blk->{value};

  # ^push names to hier
  my $stk=$bst->{$key};
  my $ptr=$st->{ptr};


  push @$stk,map {$$ARG} @$ptr;

  $scope->path(@path);

};

# ---   *   ---   *   ---
# generate translation aliases
# mostly used for asm xlate

sub alias_decl($self,$branch) {

  # get values && type
  my $st    = $branch->{value};

  my $ptr   = $st->{ptr};
  my $width = ${$ptr->[-1]}->get_bwidth();


  # get current block and offset
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $blk   = $scope->curblk();
  my $bst   = $blk->{value};

  my $pos   = $bst->{stkoff};
     $pos   = int_align($pos,$width);


  # set stack position for asm vars
  map {
    $$ARG->set_fasm_lis($pos);
    $pos+=$width;

  } @$ptr;

  # ^reset offset
  $bst->{stkoff}=$pos;

};

# ---   *   ---   *   ---
# post-parse for block instances

sub blk_ice($self,$branch) {

  $self->decl_prologue($branch);

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


  $self->decl_epilogue($branch);

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
     $blk  = $scope->haslv(@path);

  my $bst  = $blk->{value};


  # ^proc with inputs found
  if($io && $bst->{type} eq 'proc') {

    $out=[ map {(

      "$name.$ARG->{value}"=>
        $ARG->leaf_value(0)

    )} @{$io->{leaves}} ];

  };


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
# handle instancing of local vars

sub blk_ice_cl($self,$branch,@keys) {

  my $st=$branch->{value};

  # find path to blk
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my @path  = $scope->search_nc_branch(
    $st->{blk}

  );

  # fetch def
  my $blk     = $scope->get_branch(@path);
  my $bst     = $blk->{value};

  my $icepath = [$scope->path(),$st->{name}];
  my $width   = 0;

  # ^walk vars
  my %raw=map {
    $width+=$ARG->get_bwidth();
    $ARG->{id}=>$ARG->rdup($icepath);

  } @{$bst->{stk}};


  # ^make ice
  my $obj=$mach->decl(

    obj   => $st->{name},

    opath => $bst->{opath},
    procs => $bst->{procs},
    width => $width,

    raw   => \%raw,

  );


  push @{$st->{ptr}},$obj;
  $self->alias_decl($branch) if ! $st->{io};

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
# codestr out for primitive decls

sub ptr_decl_fasm_xlate($self,$branch) {


  my $st    = $branch->{value};
  my $ptr   = $st->{ptr};

  my @out   = ();


  # get current block attrs
  my $mach  = $self->{mach};
  my $scope = $mach->{scope};

  my $blk   = $scope->curblk();
  my $bst   = $blk->{value};

  my $type  = $bst->{type};
  my $attr  = $bst->{attr};

  # remove clan from path
  my @path=$scope->path();
  shift @path;


  # ^decl static vars
  if($type eq 'reg' && $attr->{static}) {

    push @out,map {
      $$ARG->fasm_data_decl(@path)

    } @$ptr;

  };


  # ^write
  $branch->{fasm_xlate}=join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
