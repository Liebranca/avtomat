#!/usr/bin/perl
# ---   *   ---   *   ---
# AVT
# avtomat utils as a package
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Avt;
  use v5.42.0;
  use strict;
  use warnings;

  use Storable qw(store);
  use Cwd qw(abs_path getcwd);

  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Log;

  use Arstd::String qw(gstrip gsplit);
  use Arstd::Path qw(reqdir relto dirof parof);
  use Arstd::Array qw(dupop);
  use Arstd::Re qw(eiths);
  use Arstd::Bin qw(orc owc);
  use Arstd::throw;

  use Shb7::Path qw(
    root
    set_root
    relto_root
    filep
    dirp
    trashp
    cachep
    memp
    configp
  );

  use Tree::File;
  use Vault;

  use Cli;

  use lib "$ENV{ARPATH}/lib/";

  use Emit::Perl;
  use Avt::Sieve;
  use Avt::Makescript;

  use parent 'St';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v3.22.0';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

my $PKG=__PACKAGE__;
St::vconst {
  DEFAULT => {
    name  => null,
    scan  => null,
    bld   => null,

    xcpy  => [],
    lcpy  => [],
    inc   => [],
    lib   => [],

    gen   => {},

    test  => {},
    util  => {},

    def   => [],
    xprt  => [],
    dep   => [],

    pre   => null,
    post  => null,
  },

  BINDIR => 'bin',
  LIBDIR => 'lib',
  INCDIR => 'include',

  GITHUB => 'https://github.com',
  LIBGIT => sub {
    return $_[0]->GITHUB . '/Liebranca';
  },

  MAKESCRIPT_DEPS=>q[
    use 5.42.0;
    use strict;
    use warnings;
    use English qw($ARG);
    use lib "$ENV{ARPATH}/lib/sys/";
    use lib "$ENV{ARPATH}/lib/";
    use Log;
    use Avt::Makescript;
  ],

  MAKESCRIPT_BODY=>q[
    my $M=Avt::Makescript->build_module(
      __FILE__,@ARGV
    );
  ],

};


# ---   *   ---   *   ---
# GBL

  my $Cache={
    config   => {},
    scan     => null,
    module   => null,

    post     => null,
    pre      => null,

    cli=>Cli->new(
      {id=>'clean',short=>'-c',argc=>0},
      {id=>'update',short=>'-u',argc=>0}
    ),

    cli_in=>[],
  };


# ---   *   ---   *   ---
# command line interface

sub read_cli($mod) {
  # get args
  my $c  = $Cache->{cli};
  my $ar = $Cache->{cli_in};

  @$ar=$c->take(@ARGV) if ! @$ar;


  # delete scan/config cache
  # to force partial re-install
  if($c->{update} ne null) {
    my $fname=Vault::px_file($mod);
    unlink $fname if -f $fname;
  };

  # ^delete compilation cache
  # triggers full recompilation!
  if($c->{clean} ne null) {
    Shb7::empty_trash($mod);
  };

  return;
};


# ---   *   ---   *   ---
# in: filepaths dst,src
# extends one perl file with another

sub plext($dst_path,$src_path) {
  # get path to both
  $dst_path=filep($dst_path);
  $src_path=filep($src_path);

  # open source
  my $src  =  orc $src_path;
     $src  =~ s[.+#:CUT;>\n][]sg;

  # ^cat destination
  my $dst  =  orc $dst_path;
     $dst  =~ s[1; # ret\n][]sg;

     $dst .= $src;


  # ^dump and give
  owc $dst_path,$dst;
  return;
};


# ---   *   ---   *   ---
# path utils
#
# args=chkpath,name,repo-url,actions
# pulls what you need

sub depchk($chkpath,$deps) {
  # switch to loc
  my $old_cwd=abs_path getcwd;
     $chkpath=abs_path $chkpath;

  chdir $chkpath;


  # bat fetch
  for(@$deps) {
    # unpack
    my ($name,$url,$act)=@$ARG;

    # pull if dir not found in provided path
    `git clone $url`
    if ! -e "$chkpath/$name";

    # still blank
    # meant for post-fetch action
    if($act) {};
  };

  # backup and give
  chdir $old_cwd;
  return;
};


# ---   *   ---   *   ---
# mirrors project structure
# into [root]/.trash/[mod]

sub mirror {
  # get ctx
  my $xkey = shift;
  my $mod  = $Cache->{module};
  my $path = dirp($mod);
  my $trsh = trashp($mod);

  # get module directory tree
  my $tree=Tree::File->new($path);
  $tree->expand(-r=>1,-x=>eiths($xkey));

  # force dump to exist
  reqdir $trsh;


  # walk dirs
  my $mod_re=qr{$mod/?$mod/};
  for($tree->get_dir_list(inclusive=>1)) {
    # don't bother with top of the tree
    next if $ARG eq $ARG->root();

    my $subpath=$ARG->get_full();
    relto_root($subpath);

    my $tdir =  "$trsh$subpath";
       $tdir =~ s[$mod_re][$mod/];

    # force dump to exist
    reqdir $tdir;
  };

  return;
};


# ---   *   ---   *   ---
# ensures trsh and bin exist
# outs file/dir list

sub scan {
  # ensure we have these standard paths
  reqdir $ARG for (
    dirp("bin"),
    dirp("lib"),
    dirp("include"),
    trashp(),
    cachep(),
    memp(),
    configp(),
  );

  # iter provided names
  my $excluded=(length $Cache->{scan})
    ? [$Cache->{scan}]
    : []
    ;

  # read module tree
  read_cli $Cache->{module};
  unshift  @$excluded,qw(
    data
    docs
    tests
    legacy
    bin

    nytprof
    __pycache__
  );

  dupop  $excluded;
  mirror $excluded;

  # recalculate module tree
  Vault->req(
    $Cache->{module},
    root(),
    $excluded,
    1,
  );

  return;
};


# ---   *   ---   *   ---
# reads build commands from config

sub get_config_build($M,$C) {
  $M->{fswat}=$C->{name};

  my $re=qr{\s+};
  my ($lmode,$mkwat)=(length $C->{bld})
    ? (split $re,$C->{bld})
    : (null,null)
    ;

  # transform x|so|ar
  if($lmode eq 'so') {
    $lmode='-shared ';

  } elsif($lmode ne 'ar') {
    $lmode=null;
  };

  $M->{lmode}=$lmode;


  # pass paths to Makescript
  my $libdir=$PKG->LIBDIR;
  my $bindir=$PKG->BINDIR;

  if(length $mkwat) {
    my @fpath=gsplit($mkwat,qr{::});
    my $fname=pop  @fpath;
    my $fpath=join '/',$libdir,@fpath;
    $M->{ilib}="$fpath/.$fname";

    if($lmode eq 'ar') {
      $M->{main}="$fpath/lib$fname.a";
      $M->{mlib}=undef;

    } elsif($lmode eq '-shared ') {
      $M->{main}="$fpath/lib$fname.so";
      $M->{mlib}=undef;

    } else {
      $M->{main}=(
        join('/',$bindir,@fpath)
      . "/$fname"
      );
      $M->{mlib}="$fpath/lib$fname.a";
    };
    $M->{mkwat}=$mkwat;


  # nothing to do ;>
  } else {
    $M->{ilib}  = undef;
    $M->{main}  = undef;
    $M->{mlib}  = undef;
    $M->{mkwat} = $M->{fswat};
  };

  return;
};


# ---   *   ---   *   ---
# do the -L/-I lines

sub get_config_paths($M,$C) {
  $M->{lib}=[
    "-L./" . $PKG->LIBDIR,
    @{$C->{lib}},
  ];

  $M->{inc}=[
    "-I./" . $PKG->INCDIR,
    "-I./",
    "-I./$C->{name}",

    @{$C->{inc}},
  ];

  return;
};


# ---   *   ---   *   ---
# filters out file list using config
# writes results to makescript

sub get_config_files($M,$C,$module) {
  my @dirs=$module->get_dir_list(
    full=>0,
    inclusive=>1
  );

  my $sieve=Avt::Sieve->new(
    makescript => $M,
    config     => $C,
    bindir     => $PKG->BINDIR,
    libdir     => $PKG->LIBDIR,
  );

  $sieve->iter(\@dirs);
  return;
};

# ---   *   ---   *   ---
# invert generator hash
#
#   > from: generated=>[generator,dependencies]
#     to: generator=>[generated,dependencies]
#
# the reason why is the first form makes more
# sense visually (at least to me), so that's
# what i'd rather write to a config file
#
# however, the second form is more convenient
# for a file search, so...

sub invert_generator($dst) {
  my %inverted=();

  for my $outfile(keys %$dst) {
    my @srcs=@{$dst->{$outfile}};
    my $exec=$srcs[0];

    $inverted{$exec}=[
      $outfile,@srcs[1..$#srcs]
    ];
  };

  $dst={%inverted};
  return;
};


# ---   *   ---   *   ---
# emits builders

sub make {
  my $C         = $Cache->{config};
  my $mod       = Vault::module($Cache->{module});
  my $avto_path = filep("$C->{name}/avto");


  # build the makescript object
  my $M=Avt::Makescript->new();
  get_config_build($M,$C);
  get_config_paths($M,$C);
  get_config_files($M,$C,$mod->{tree});

  # save it to disk
  my $cache_path=filep("$C->{name}/.avto-cache");
  store($M,$cache_path) or throw $cache_path;


  # now dump the boiler
  open my $FH,'>',$avto_path or throw $avto_path;
  my $FILE=null;

  # get file contents
  $FILE .= "#!/usr/bin/perl\n";
  $FILE .= $PKG->MAKESCRIPT_DEPS;
  $FILE .= hook_str(pre=>$M,$C);
  $FILE .= $PKG->MAKESCRIPT_BODY;
  $FILE .= hook_str(post=>$M,$C);

  # ^erradicate blanks
  $FILE  = join "\n",(gstrip split qr"\n",$FILE);
  $FILE .= "\n1;";


  # ^write makefile
  print {$FH} $FILE;
  close $FH;

  `chmod +x "$avto_path"`;
  return;
};


# ---   *   ---   *   ---
# pastes codestr for hook

sub hook_str($which,$M,$C) {
  my $blkbeg=($which eq 'pre')
    ? "INIT { Log->mupdate('$M->{fswat}');"
    : 'END {'
    ;

  my @blklog=(
    ($which eq 'post')
      ? q[if(! defined $M) {
          say "Build failed";
          exit -1
        }]

      : ()
      ,

    "Log->step(\"running $which-build hook\\n\");",

  );

  my $blkend=($which eq 'post')
    ? '$M->depsmake();'
    . 'Log->step("done\n\n");'
    : null
    ;

  return join "\n",grep {
    length $ARG

  } ($blkbeg,@blklog,$C->{$which},$blkend,'};');
};


# ---   *   ---   *   ---
# registers module configuration,
# then runs the build

sub config($C) {
  # no filepath passed?
  if(! exists $C->{fpath}) {
    # assume caller *is* config file
    my ($pkgname,$file,$line)=caller;
    $C->{fpath}=$file;
  };

  # ^ root is always one level above the
  #   config file's directory
  $C->{root}=parof(dirof($C->{fpath}),i=>1);
  set_root($C->{root});

  my $sep_re       = q{\s*,\s*};
  my $list_to_hash = qr{(?:lcpy|xcpy|xprt)}x;

  # set defaults
  $PKG->defnit($C);

  # convert file lists to hashes
  for(grep {$ARG=~ $list_to_hash} keys %$C) {
    my @expand=map {glob($ARG)} @{$C->{$ARG}};
    $C->{$ARG}={map {$ARG=>1} @expand};
  };

  # run dependency checks
  depchk(dirp($C->{name}),$C->{dep})
  if $C->{dep};

  # prepare the libs && includes
  for(@{$C->{lib}}) {
    $ARG=(0 <= index $ARG,'/')
      ? "-L$ARG"
      : "-l$ARG"
      ;
  };

  $ARG="-I./$ARG" for @{$C->{inc}};


  # from result=>[src,deps]
  # to   src=>[result,deps]
  invert_generator($C->{gen});
  invert_generator($C->{test});
  invert_generator($C->{util});

  # register, run and give
  $Cache->{module} = $C->{name};
  $Cache->{scan}   = $C->{scan};
  $Cache->{config} = $C;

  scan;
  make;
  return;
};


# ---   *   ---   *   ---
1; # ret
