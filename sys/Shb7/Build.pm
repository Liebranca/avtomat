#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 BUILD
# Bunch of gcc wrappers
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Shb7::Build;

  use v5.36.0;
  use strict;
  use warnings;

  use Cwd qw(getcwd);
  use English qw(-no_match_vars);

  use Storable;
  use Readonly;
  use Carp;

  use Exporter 'import';

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::IO;
  use Arstd::WLog;

  use Shb7::Path;
  use Shb7::Find;

  use Shb7::Bk::gcc;
  use Shb7::Bk::flat;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# adds to your namespace

  our @EXPORT=qw(

    push_makedeps
    clear_makedeps

    obj_file
    obj_dir

  );

# ---   *   ---   *   ---
# ROM

  my $FLGCHK=sub {

     defined $ARG
  && 2<length $ARG

  };

# ---   *   ---   *   ---
# GBL

  our $Makedeps={
    objs=>[],
    deps=>[]

  };

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{name}    //= 'out';
  $O{entry}   //= '_start';

  $O{lang}    //= 'fasm';
  $O{files}   //= [];
  $O{incl}    //= [];
  $O{libs}    //= [];

  $O{shared}  //= 0;
  $O{linking} //= 0;
  $O{debug}   //= 0;
  $O{tgt}     //= $Shb7::Bk::TARGET->{x64};


  # condtionally add extra flags
  my $flags=[];

  unshift @$flags,q[-shared]
  if $O{shared};

  unshift @$flags,q[-g]
  if $O{debug};


  # make ice
  my $self=bless {

    name    => $O{name},
    files   => $O{files},
    entry   => $O{entry},

    incl    => $O{incl},
    libs    => $O{libs},

    flags   => $flags,
    linking => $O{linking},
    tgt     => $O{tgt},

    lang    => $O{lang},

  },$class;

  # ^build meta
  $self->get_module_deps();
  $self->get_module_paths();


  return $self;

};

# ---   *   ---   *   ---
# adds to builder's file array

sub push_files($self,@data) {
  push @{$self->{files}},@data;

};

# ---   *   ---   *   ---
# adds to builder's flags array

sub push_flags($self,@data) {
  push @{$self->{flags}},@data;

};

# ---   *   ---   *   ---
# these are for generating mam's dependency lists
# in a nutshell: it's a hack

sub push_makedeps($obj,$dep) {
  push @{$Makedeps->{objs}},$obj;
  push @{$Makedeps->{deps}},$dep;

};

sub clear_makedeps() {
  $Makedeps={objs=>[],deps=>[]};

};

# ---   *   ---   *   ---
# shortcuts

sub obj_file($path) {
  return $Shb7::Path::Trash.$path

};

sub obj_dir($path=$NULLSTR) {
  return $Shb7::Path::Trash.$path.q[/];

};

# ---   *   ---   *   ---
# get dependencies for a module
# from build metadata

sub get_module_deps($self) {

  my @found=();
  my @paths=();

  array_filter($self->{libs});
  array_filter($self->{incl});

  while(@{$self->{libs}}) {

    # skip -L
    my $path=shift @{$self->{libs}};
    if($path=~ $LIBD_RE) {
      push @paths,$path;
      next;

    };

    my $lib=$path;

    # remove -l and get path to module
    $path=~ s[$LIBF_RE][];
    $path=Shb7::Find::build_path($path);

    # retrieve build data if present
    if(-d $path) {

      my $meta=Shb7::Find::build_meta($path);

      push @{$self->{incl}},@{$meta->{incl}};
      push @found,$lib,@{$meta->{libs}};

    } else {
      push @found,$lib;

    };

  };

  push @{$self->{libs}},@paths;
  push @{$self->{libs}},@found;

};

# ---   *   ---   *   ---
# get current search paths

sub get_module_paths($self) {

  for my $lib(@{$Shb7::Path::Lib}) {
    unshift @{$self->{libs}},q[-L].$lib;

  };

  for my $incl(@{$Shb7::Path::Include}) {
    unshift @{$self->{incl}},q[-I].$incl;

  };

  array_filter($self->{incl},$FLGCHK);
  array_filter($self->{libs},$FLGCHK);

  array_dupop($self->{incl});
  array_dupop($self->{libs});

};

# ---   *   ---   *   ---
# return list of build files

sub list_obj($self) {

  return map {
    $ARG->{obj}

  } grep {
    ! defined $ARG->{__alt_out}

  } @{$self->{files}};

};

sub list_src($self) {
  return map {
    $ARG->{src}

  } @{$self->{files}};

};

sub list_dep($self) {
  return map {
    $ARG->{dep}

  } @{$self->{files}};

};

# ---   *   ---   *   ---
# standard call to link object files

sub link_cstd($self,@obj) {

  return (

    q[gcc],

    @{$Shb7::Bk::gcc::OFLG},
    @{$Shb7::Bk::gcc::LFLG},
    @{$self->{flags}},

    Shb7::Bk::gcc::target($self->{tgt}),

    @{$self->{incl}},
    @obj,

    q[-o],$self->{name},
    @{$self->{libs}},

  );

};

# ---   *   ---   *   ---
# ^similar, but fine-tuned for nostdlib
# what I *usually* use with assembler *.o files

sub link_half_flat($self,@obj) {

  return (

    q[gcc],

    @{$Shb7::Bk::gcc::FLATLFLG},
    @{$self->{flags}},

    Shb7::Bk::gcc::entry($self->{entry}),
    Shb7::Bk::gcc::target($self->{tgt}),

    @{$self->{incl}},
    @obj,

    q[-o],$self->{name},
    @{$self->{libs}},

  );

};

# ---   *   ---   *   ---
# extreme ld-only setup
# meant for teensy assembler binaries

sub link_flat($self,@obj) {

  return (

    q[ld.bfd],

    qw(--relax --omagic -d),
    qw(--gc-sections),

    Shb7::Bk::flat::entry($self->{entry}),
    Shb7::Bk::flat::target($self->{tgt}),

    q[-o],$self->{name},

    @obj,
    @{$self->{libs}},

  );

};

# ---   *   ---   *   ---
# fake linking for java!

sub link_jar($self,@obj) {

  # building lib?
  my $shared=defined array_iof(
    $self->{flags},'-shared'

  );

  my $manipath = 'META-INF/MANIFEST.MF';


  # remember current path
  my $old_path=getcwd();


  # walk objects
  my @jar=map {


    # get file and extraction folder
    my $jar    = $ARG;
    my $jardir = dirof($jar);

    mkdir "$jardir/.linking"
    if ! -d "$jardir/.linking";


    # get all *.class files in *.jar
    my @classes=
      grep  {$ARG=~ qr{\.class$}}
      split "\n",`jar -tf $jar`

    ;


    # extract classes+manifest in jar dir
    chdir "$jardir/.linking";

    my $classes=join ' ',@classes;
    `jar -xf $jar $classes $manipath`;


    # read manifest into hash
    my $manifest={

      map   {split ': ',$ARG}
      grep  {length $ARG}

      split "\r\n",orc($manipath)

    };


    { manifest => $manifest,

      linkpath => "$jardir/.linking",
      classes  => \@classes,

    };


  } @obj;


  # reset path
  chdir $old_path;

  my $dst=(! ($self->{name}=~ qr{\.jar$}))
    ? "$self->{name}.jar"
    : $self->{name}
    ;


  # roll jars together
  my $manifest={
    'Created-By' => [],
    'Class-Path' => [],

  };

  map {

    my $src=$ARG;

    # combine manifest
    map {

      # list fields
      if($ARG=~ qr{(?:
        Created\-By
      | Class-Path

      )}x) {

        push @{$manifest->{$ARG}},
          $src->{manifest}->{$ARG};

      # catch multiple main
      } elsif($ARG eq 'Main-Class'
      && exists $manifest->{$ARG}) {

        say {*STDERR}
          'link_jar: multiple main classes';

        exit -1;


      # all OK, just paste
      } else {

        $manifest->{$ARG} //= $NULLSTR;
        $manifest->{$ARG}  .=
          $src->{manifest}->{$ARG};

      };


    } keys %{$src->{manifest}};

  } @jar;


  # credit the AR/bois
  push @{$manifest->{'Created-By'}},
    'AR/avtomat';

  $manifest->{'Created-By'}=join ',',
    @{$manifest->{'Created-By'}};


  # stringify manifest
  $manifest=join "\r\n",grep {
    length $ARG

  # proc each field
  } map {

      my $value   = $manifest->{$ARG};
         $value //= $NULLSTR;


      # stringify arrays
      if(is_arrayref($value)) {
        $value=join ' ',@$value;

      };

      # skip blank fields
      (length $value)
        ? join ': ',$ARG,$value
        : $NULLSTR
        ;

  } qw(

    Manifest-Version
    Created-By
    Main-Class
    Class-Path

  );


  # put manifest in archive
  owc(".manifest","$manifest\r\n\r\n");
  `jar -cfm $dst .manifest`;

  unlink '.manifest';


  # put classes in archive
  map {

    my $src   = $ARG;

    my $path  = $src->{linkpath};
    my $files = join ' ',@{$src->{classes}};

    `jar -ufv $dst -C $path $files`;

  } @jar;


  return;

};

# ---   *   ---   *   ---
# object file linking

sub olink($self) {

  # get object file names
  my @obj  = $self->list_obj();
  my @miss = grep { ! -f $ARG} @obj;

  # nothing to do?
  if(! @obj) {
    $WLog->step("no linking needed");
    return;

  };


  # ^chk all exist
  if(@miss) {

    map {
      $WLog->step("missing file $ARG");

    } @miss;

    exit -1;

  };


  # select cmd generator
  my @call=();

  # ^using gcc
  if($self->{linking} eq 'cstd') {
    @call=$self->link_cstd(@obj);

  # ^gcc, but fine-tuned
  } elsif($self->{linking} eq 'half-flat') {
    @call=$self->link_half_flat(@obj);

  # ^using ld ;>
  } elsif($self->{linking} eq 'flat') {
    @call=$self->link_flat(@obj);

  } elsif($self->{linking} eq 'jar') {
    @call=$self->link_jar(@obj);

  };


  # ^issue cmd
  array_filter(\@call);
  system {$call[0]} @call if @call;

};

# ---   *   ---   *   ---
# symrd errme

sub throw_no_shwl($name,$path) {

  errout(

    q[Can't find shadow lib for '%s' <%s>],

    args => [$name,$path],
    lvl  => $AR_ERROR,

  );

};

# ---   *   ---   *   ---
# get symbol typedata from shadow lib

sub symrd($mod) {

  my $out={};
  my $src=libdir().".$mod";

  # existence check
  if(! -f $src) {
    throw_no_shwl($mod,$src);

  } else {
    $out=retrieve($src)
    or croak strerr($src);

  };

  return $out;

};

# ---   *   ---   *   ---
# reads symbol table entry

sub symtab_read(

  $symtab,

  $lib,
  $path,
  $rebuild

) {

  my $f=symrd($lib);

  # so regen check
  if(!$$rebuild) {
    $$rebuild=ot($path,ffind('-l'.$lib));

  };

  # append
  for my $o(keys %{$f->{objects}}) {

    my $obj=$f->{objects}->{$o};

    $symtab->{objects}->{
      $Shb7::Path::Root.$o

    }=$obj;

  };

  push @{$symtab->{deps}},$f->{deps};

};

# ---   *   ---   *   ---
# creates a shared object based on
# the provided shwl symbol table

sub so_from_symtab($symtab,$path,@libs) {

  map {$ARG="-l$ARG"} @libs;
  @libs=(@libs,map {@$ARG} @{$symtab->{deps}});

  my @objs=map {
    {obj=>$ARG}

  } keys %{$symtab->{objects}};

  my $bld=Shb7::Build->new(

    name    => $path,

    files   => \@objs,
    libs    => \@libs,

    shared  => 1,
    linking => 'cstd',

  );

  $bld->olink();

};

# ---   *   ---   *   ---
# rebuilds shared objects if need be

sub soregen($name,$libs_ref,$no_regen=0) {

  my $path    = so($name);
  my $rebuild = ! -f $path;

  my @libs=@{$libs_ref};
  my $symtab={

    deps=>[],
    objects=>{}

  };

  # recover symbol table
  for my $lib(@libs) {
    symtab_read($symtab,$lib,$path,\$rebuild);

  };

  # generate so
  if($rebuild && !$no_regen) {
    so_from_symtab($symtab,$path,@libs);

  };

  return $symtab;

};

# ---   *   ---   *   ---
1; # ret
