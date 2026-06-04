#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO CFG
# reads config file
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::cfg;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_file is_arrayref);
  use St qw(defnit);

  use Arstd::String qw(catpath gsplit);
  use Arstd::Path qw(parof dirof basef);
  use Arstd::Array qw(dupop to_hash);
  use Arstd::Re qw(eiths);
  use Arstd::PM qw(lrcaller);
  use Arstd::rd;
  use Arstd::throw;

  use Shb7::Path qw(
    swap_root
    from_config
    libdirp
  );
  use avto::shwl;


# ---   *   ---   *   ---
# ROM

sub bindir {return 'bin'};
sub libdir {return 'lib'};
sub incdir {return 'include'};

sub DEFAULT {return {
  map {$ARG=>[]} qw(
    name skip bld
    xprt xcpy lcpy
    gen util test
    pre post boot
    arch obc link
    strip debug entry shared
    inc lib def output
  )
}};


# ---   *   ---   *   ---
# entry point

sub new {
  my ($class,$src)=@_;

  # get ice from source
  my $cfg=bless {rd($src)},$class;

  # set defaults and run value conversions
  $class->defnit($cfg);
  $cfg->proc();

  return $cfg;
};


# ---   *   ---   *   ---
# loads config

sub load {
  my ($cfg,%O)=@_;
  $O{roll} //= 0;
  $O{rev}  //= 0;

  my $root=[$cfg->{root},"$ENV{ARPATH}"];
     $root=[reverse @$root] if $O{rev};

  return from_config(
    catpath(avtomat=>'defv.cfg'),
    roll=>$O{roll},
    root=>$root,
  );
};


# ---   *   ---   *   ---
# all values extracted from *.cfg files are
# string arrays, so handle conversions here

sub proc {
  my ($cfg)=@_;

  # first off get source and destination
  $cfg->proc_fpath();
  $cfg->proc_defv();
  $cfg->proc_bld();

  # convert code blocks to strings
  $cfg->{$ARG}=join(' ',@{$cfg->{$ARG}})
  for qw(boot pre post);

  # convert skip to a regex
  $cfg->proc_skip();

  # setup libs and includes
  $cfg->proc_lib();
  $cfg->proc_inc();

  # convert miscellaneous gcc switches
  $cfg->proc_switch();

  return;
};


# ---   *   ---   *   ---
# set the name, fpath and root fields

sub proc_fpath {
  my ($cfg)=@_;

  # no filepath passed?
  if(! exists $cfg->{fpath}) {
    # assume caller *is* config file
    my ($pkg,$file,$line)=lrcaller(ref $cfg);
    $cfg->{fpath}=$file;
  };

  # ^ root is always one level above the
  #   config file's directory
  $cfg->{root}=parof(dirof($cfg->{fpath}));

  # project name should always match directory
  $cfg->{name}=basef(dirof($cfg->{fpath}));

  return;
};


# ---   *   ---   *   ---
# perform addition or override
# of keys, using values defined
# in avtomat's own config file

sub proc_defv {
  my ($cfg)=@_;
  my $defv={load($cfg,roll=>0)};

  for(keys %$defv) {
    next if! exists DEFAULT()->{$ARG};

    # in the case of these, we want to *add*
    # them to the configuration rather than
    # strictly set their value
    if($ARG=~ qr{^(?:boot|def|lib|inc|skip)$}) {
      unshift @{$cfg->{$ARG}},@{$defv->{$ARG}};

    # ^ for everything else, we only use the
    #   default if the value was omitted or
    #   left blank
    } elsif(! @{$cfg->{$ARG}}) {
      $cfg->{$ARG}=$defv->{$ARG};
    };
  };
  return;
};


# ---   *   ---   *   ---
# read the 'bld' field

sub proc_bld {
  my ($cfg)=@_;
  my $name=$cfg->{bld}->[1] // $cfg->{name};
  my $path=$cfg->proc_bld_path($name);
  my ($obc,$link,$arch)=$cfg->proc_bld_tgt();

  $cfg->{bld}={
    name => $name,
    mode => $cfg->proc_bld_mode(),
    path => $path,
    obc  => $obc,
    link => $link,
    arch => $arch,
  };
  return;
};


# ---   *   ---   *   ---
# ^get all possible output paths

sub proc_bld_path {
  my ($cfg,$name)=@_;

  my $out   = {};
  my @fpath = gsplit($name,qr{::});
  my $fname = pop @fpath;
  my $fpath = catpath(libdirp(),@fpath);

  $out->{sl}=catpath(
    $fpath,
    "$fname."
  . avto::shwl::fext()
  );
  $out->{ar}="$fpath/lib$fname.a";
  $out->{so}="$fpath/lib$fname.so";
  $out->{ex}=catpath($cfg->bindir(),@fpath,$fname);

  return $out;
};


# ---   *   ---   *   ---
# ^validates mode

sub proc_bld_mode {
  my ($cfg,$path)=@_;
  return null if ! defined $cfg->{bld}->[0];

  my @tab  = qw(x ar so);
  my $mode = $cfg->{bld}->[0];
  throw "avto: unrecognized build mode '$mode'"
  if!   int grep {$mode eq $ARG} @tab;

  return $mode;
};


# ---   *   ---   *   ---
# read and validate link/arch options

sub proc_bld_tgt {
  my ($cfg)=@_;
  my ($obc,$link,$arch)=(
    $cfg->{obc},
    $cfg->{link},
    $cfg->{arch},
  );

  # set defaults for obc/link
  $obc  = ['cstd'] if! @$obc;
  $link = ['cstd'] if! @$link;
  $arch = ['x64']  if! @$arch;

  # cleanup and give
  delete $cfg->{obc};
  delete $cfg->{link};
  delete $cfg->{arch};

  return ($obc,$link,$arch);
};


# ---   *   ---   *   ---
# turn list of paths into regex

sub proc_skip {
  my ($cfg)=@_;
  $ARG="\Q$ARG" for @{$cfg->{skip}};
  $cfg->{skip}=eiths($cfg->{skip});

  return;
};


# ---   *   ---   *   ---
# reads lists of libraries and sorts
# them into files and directories

sub proc_lib {
  my ($cfg)=@_;
  my ($dir,$file)=(
    ["./" . $cfg->libdir()],
    []
  );
  for(@{$cfg->{lib}}) {
    if(0 <= index($ARG,'/')) {
      push @$dir,$ARG;

    } else {
      push @$file,$ARG;
    };
  };
  dupop($dir);
  dupop($file);

  $cfg->{lib}={dir=>$dir,file=>$file};
  return;
};


# ---   *   ---   *   ---
# adds default paths to includes

sub proc_inc {
  my ($cfg)=@_;
  unshift @{$cfg->{inc}},(
    "./" . $cfg->incdir(),
    "./",
    "./" . $cfg->{name},
  );
  dupop($cfg->{inc});

  return;
};


# ---   *   ---   *   ---
# miscellaneous conversion of switches
#
# these exist to more completely interface
# with gcc

sub proc_switch {
  my ($cfg)=@_;

  # handle bools
  for(qw(debug strip shared)) {
    my $ar=$cfg->{$ARG};
    $cfg->{$ARG}=(@$ar)
      ? int($ar->[0])
      : 0
      ;
  };

  # handle strings
  for(qw(entry output)) {
    my $ar=$cfg->{$ARG};
    $cfg->{$ARG}=(@$ar)
      ? join(' ',@$ar)
      : undef
      ;
  };

  # ^handle defaults
  $cfg->{entry}  //= '_start';
  $cfg->{output} //= null;

  return;
};



# ---   *   ---   *   ---
1; # ret
