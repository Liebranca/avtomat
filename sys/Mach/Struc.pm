#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH STRUC(-ture)
# Labels on a segment
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach::Struc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use List::Util qw(min);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::String;
  use Arstd::IO;
  use Arstd::PM;

  use Mach::Seg;

  use parent 'St';

# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(struc strucs);

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  sub Frame_Vars($class) {return {

    -autoload=>[qw()],

  }};

  Readonly our $FIELD_RE=>qr{
    (?<type> [^<\s]+) \s+
    (?<bare> [^;]+) \s* ; \s*

  }x;

  Readonly our $NAME_RE=>qr{
    < (?<name> [^>]+) > \s*

  }x;

  Readonly our $STRUC_RE=>qr{(?<struc>

    ^ \s*
      $NAME_RE
      $FIELD_RE+

  )}x;

# ---   *   ---   *   ---
# partial beq from Mach::Seg
#
# done so sub-structures can
# be treated as segments

  beqwraps('-seg',qw(

    encode_ptr

    to_bytes
    get
    from_bytes

    set
    iof

  ));

# ---   *   ---   *   ---
# GBL

  our $Icebox={};
  our $Cstruc={};

  our $Sizeof={%$PESZ};

# ---   *   ---   *   ---
# get table of instance arrays

sub _icebox_tab($class) {
  no strict 'refs';
  return ${"$class\::Icebox"};

};

# ---   *   ---   *   ---
# get table of constructors

sub _cstruc_tab($class) {
  no strict 'refs';
  return ${"$class\::Cstruc"};

};

# ---   *   ---   *   ---
# get table of type sizes for class

sub _sizeof_tab($class) {
  no strict 'refs';
  return ${"$class\::Sizeof"};

};

# ---   *   ---   *   ---
# ^fetch

sub sizeof($class,$key) {

  my $tab=$class->_sizeof_tab();

  errout(

    q[Invalid type '%s'],

    lvl  => $AR_FATAL,
    args => [$key],

  ) unless exists $tab->{$key};

  return $tab->{$key};

};

# ---   *   ---   *   ---
# get ice is valid seg or struc
# return seg or struc->{-seg} if so

sub validate($class,$ice) {

  return $ice if Mach::Seg->is_valid($ice);
  return $ice->{-seg} if $class->is_valid($ice);

  return undef;

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$name,@fields) {

  # redecl guard
  errout(

    q[Redeclaration of type '%s'],

    lvl  => $AR_FATAL,
    args => [$name],

  ) unless ! exists $Icebox->{$name};

  # make tab from array
  my %methods = $class->split_fields(\@fields);
  my %fields  = @fields;

  # ^pop special flags
  my $attrs   = $fields{-attrs};
     $attrs //= [];

  delete $fields{-attrs};
  @fields=grep {
      $ARG ne '-attrs'
  &&! is_arrayref($ARG)

  } @fields;

  # ^walk
  my ($sizes,$total)=
    $class->calc_size(\%fields,\@fields);

  # ^make icewraps
  my $cstruc={

    name    => $name,
    attrs   => $attrs,

    methods => \%methods,
    fields  => \@fields,

    sizes   => $sizes,
    total   => $total,

  };

  # ^put in icebox
  $class->_cstruc_tab()->{$name}=$cstruc;
  $class->_sizeof_tab()->{$name}=$total;

  return $cstruc;

};

# ---   *   ---   *   ---
# ^sweetcrux

sub struc($expr,$pkg=undef) {

  # defaults
  $pkg //= caller;

  # remove comments
  strip(\$expr);
  comstrip(\$expr);

  # throw if expr doesn't match re
  errout(

    q[BADSTRUC: "%s"],

    lvl  => $AR_FATAL,
    args => [$expr],

  ) unless $expr=~ $STRUC_RE;


  # accum vars
  my $name  = $NULLSTR;
  my $type  = [];
  my $bare  = [];
  my $attrs = [];

  # get <name-of-struc>
  $expr=~ s[$NAME_RE][];
  $name=$+{name};


  # get type field;type field;
  while($expr=~ s[$FIELD_RE][]) {
    push @$type,$+{type};
    push @$bare,$+{bare};

  };

  # ^pack
  my @fields=map {

    my $t=shift @$type;
    my $b=shift @$bare;

    # arg is method
    if(0 == index $b,'&') {

      my $fn=codefind(
        $pkg,(substr $b,1,length $b)

      # ^throw if not found
      ) or errout(

        q[No '%s' in pkg <%s>],

        lvl  => $AR_FATAL,
        args => [$b,$pkg],

      );

      $t=>$fn;

    # ^arg is attribute
    } elsif($t eq 'wed') {

      my ($name,$value)=(split q[ ],$b);

      $value//=1;

      push @$attrs,$name=>$value;
      undef;

    # ^arg is data field
    } else {
      $b=>$t;

    };

  } 0..int(@$type)-1;


  # cat attributes as special field
  array_filter(\@fields);
  push @fields,'-attrs'=>$attrs;

  return Mach::Struc->new($name,@fields);

};

# ---   *   ---   *   ---
# ^bat

sub strucs($expr) {

  my @out=();
  my $pkg=caller;

  # remove comments
  strip(\$expr);
  comstrip(\$expr);

  # manually recurse pattern
  while($expr=~ s[$STRUC_RE][]) {
    push @out,struc($+{struc},$pkg);

  };

  # ^throw if expr not fully consumed
  errout(

    q[BADSTRUCS: "%s"],

    lvl  => $AR_FATAL,
    args => [$expr],

  ) unless ! length $expr;

  return @out;

};

# ---   *   ---   *   ---
# separates methods from
# struc fields

sub split_fields($class,$ar) {

  my %out  = ();
  my @move = ();

  my $i=0;map {

    my $value=$ar->[$i+1];

    if(is_coderef($value)) {
      $out{$ARG}=$value;

    } else {
      push @move,$ARG=>$value;

    };

    $i+=2;

  } array_keys($ar);

  @$ar=@move;
  return %out;

};

# ---   *   ---   *   ---
# ^invokes methods of struc

sub AUTOLOAD($self,@args) {

  our $AUTOLOAD;

  my $key    = $AUTOLOAD;
  my $class  = ref $self;

  # abort if dstruc
  return if ! autoload_prologue(\$key);

  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$self->{-type}};

  # abort if method not found
  my $fn=$cstruc->{methods}->{$key}
  or throw_bad_autoload($self->{-type},$key);

  return $fn->($self,@args);

};

# ---   *   ---   *   ---
# get total size of struc

sub calc_size($class,$h,$ar) {

  my $offset = 0;
  my $total  = 0;
  my $size   = 0;

  # ^walk individual size of field types
  my $tab={map {

    $offset  = $total;
    $size    = $class->sizeof($h->{$ARG});
    $total  += $size;

    $ARG    => [$offset,$size];

  } array_keys($ar)};

  return $tab,$total;

};

# ---   *   ---   *   ---
# get field count for structure

sub field_cnt($class,$name) {

  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$name};

  my $fields = $cstruc->{fields};

  return (int @$fields)/2;

};

# ---   *   ---   *   ---
# make copy of struc for usage

sub ice($class,$name,%O) {

  my $icebox = $class->_icebox_tab();
  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$name};

  $O{attrs}=$cstruc->{attrs};

  # ^run constructor
  my ($seg,$div,$labels)=
    $class->calc_segment($cstruc,%O);

  # ^make ice
  my $self=bless {

    -seg    => $seg,
    -type   => $name,
    -fields => [keys %$labels],
    -attrs  => [@{$cstruc->{attrs}}],

    -div    => $div,

    %$labels,

  },$class;

  # ^store
  $icebox->{$name}//=[];
  push @{$icebox->{$name}},$self;

  return $self;

};

# ---   *   ---   *   ---
# make new segment and apply
# recursive subdivisions

sub calc_segment($class,$cstruc,%O) {

  # defaults
  $O{offset} //= 0;


  my $seg;

  # make new segment if none provided
  if(! exists $O{segref}) {

    $seg=Mach::Seg->new(
      $cstruc->{total},
      mach=>$O{mach},

    );

  # ^else point
  } else {

    my %attrs=@{$O{attrs}};

    $seg=$O{segref}->point(

      $O{offset},
      $cstruc->{total},

      %attrs,

    );

  };

  # ^subdivide
  my @names  = array_keys($cstruc->{fields});

  my %stride = ();
  my $prev   = $O{offset};

  my $div=[map {

    # adjust offsets into seg
    my ($offset,$width)=
      @{$cstruc->{sizes}->{$ARG}};

    $stride{$ARG}=$offset;
    $prev=$offset;

    # from [name => type]
    # to   [name => ptr]
    $ARG=>$seg->put_label(
      $ARG,$offset,$width

    );

  } @names];

  my $labels={@$div};

  # make tab from array
  my %fields=@{$cstruc->{fields}};

  # ^recurse
  for my $key(@names) {

    # skip primitives
    my $type=$fields{$key};
    next if exists $PESZ->{$type};

    # copy sub-segments of a sub-struc
    $labels->{$key}=$class->ice(

      $type,

      segref=>$seg,
      offset=>$stride{$key},

    );

  };

  return $seg,$div,$labels;

};

# ---   *   ---   *   ---
# debug out

sub prich($self,%O) {

  # defaults
  $O{errout}//=0;
  $O{fields}//=[];

  # get ctx
  my $class  = ref $self;
  my $tab    = $class->_cstruc_tab();
  my $cstruc = $tab->{$self->{-type}};
  my $sizes  = $cstruc->{sizes};

  # detail fields
  my @keys = array_keys($self->{-div});
  my $req  = $O{fields};

  # catch non-existent keys
  # if specific fields requested
  if(@$req) {

    @keys=map {

      throw_no_field($self->{-type},$ARG)
      if ! exists $self->{$ARG};

      $ARG;

    } @$req;

  };

  my $me   = $NULLSTR;

  for my $key(@keys) {

    my $width = min(8,$sizes->{$key}->[1]);
    my $cpl   = int(16/$width);
    my $ice   =  $self->{$key};

    my @bytes = ($width >= 16)
      ? reverse $ice->to_bytes($width*8)
      : $ice->get()
      ;

    my $fmat  = xe(

      \@bytes,

      word=>$width,
      line=>$cpl,
      drev=>$width < 16,

    );

    $me.=".$key\n$fmat\n\n";

  };

  # select and spit
  my $fh=($O{errout})
    ? *STDERR
    : *STDOUT
    ;

  say {$fh} $me;

};

# ---   *   ---   *   ---
# ^errme

sub throw_no_field($name,$key) {

  errout(

    q[Struc [ctl]:%s has no field [err]:%s],

    lvl  => $AR_FATAL,
    args => [$name,$key],

  );

};

# ---   *   ---   *   ---
1; # ret
