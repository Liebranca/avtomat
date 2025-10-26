#!/usr/bin/perl
# ---   *   ---   *   ---
# SHB7 LINK
# objects galore
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Shb7::Link;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(getcwd);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_arrayref);

  use Arstd::Array qw(filter iof);
  use Arstd::Path qw(reqdir dirof);
  use Arstd::Bin qw(owc);
  use Arstd::throw;

  use Shb7::Bk;
  use Shb7::Bk::gcc;
  use Shb7::Bk::flat;

  use Log;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(olink);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.9';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# standard call to link object files

sub link_cstd($self,@obj) {
  return (
    q[gcc],

    Shb7::Bk::gcc::oflg(),
    Shb7::Bk::gcc::lflg(),
    @{$self->{flag}},

    Shb7::Bk::gcc::target($self->{tgt}),

    @{$self->{inc}},
    @obj,

    q[-o],$self->{name},
    @{$self->{lib}},
  );
};


# ---   *   ---   *   ---
# ^similar, but fine-tuned for nostdlib
# what I *usually* use with assembler *.o files

sub link_half_flat($self,@obj) {
  return (
    q[gcc],

    Shb7::Bk::gcc::flatflg(),
    @{$self->{flag}},

    Shb7::Bk::gcc::entry($self->{entry}),
    Shb7::Bk::gcc::target($self->{tgt}),

    @{$self->{inc}},
    @obj,

    q[-o],$self->{name},
    @{$self->{lib}},
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
    @{$self->{lib}},
  );
};


# ---   *   ---   *   ---
# fake linking for java!

sub link_jar($self,@obj) {
  # building lib?
  my $shared=defined iof(
    $self->{flag},'-shared'
  );

  my $manipath='META-INF/MANIFEST.MF';


  # remember current path
  my $old_path=getcwd();

  # walk objects
  my @jar=map {
    # get file and extraction folder
    my $jar    = $ARG;
    my $jardir = dirof($jar);

    reqdir("$jardir/.linking");


    # get all *.class files in *.jar
    my @classes=(
      grep  {$ARG=~ qr{\.class$}}
      split "\n",`jar -tf $jar`
    );

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

    # give object for file
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

  for(@jar) {
    my $src=$ARG;

    # combine manifest
    for(keys %{$src->{manifest}}) {
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
        throw 'link_jar: multiple main classes';

      # all OK, just paste
      } else {
        $manifest->{$ARG} //= null;
        $manifest->{$ARG}  .=
          $src->{manifest}->{$ARG};
      };
    };

  };


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
         $value //= null;

      # stringify arrays
      if(is_arrayref($value)) {
        $value=join ' ',@$value;
      };

      # skip blank fields
      (length $value)
        ? join ': ',$ARG,$value
        : null
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
  for(@jar) {
    my $src   = $ARG;

    my $path  = $src->{linkpath};
    my $files = join ' ',@{$src->{classes}};

    `jar -ufv $dst -C $path $files`;

  };

  return;
};


# ---   *   ---   *   ---
# object file linking

sub olink($self) {
  # get object file names
  my @obj  = $self->list_obj();
  my @miss = grep { ! is_file($ARG)} @obj;

  # nothing to do?
  if(! @obj) {
    Log->step("no linking needed");
    return;
  };

  # ^chk all exist
  if(@miss) {
    Log->step("missing file $ARG") for @miss;
    throw "OLINK aborted";
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
  filter(\@call);
  system {$call[0]} @call if @call;

  return;
};


# ---   *   ---   *   ---
1; # ret
