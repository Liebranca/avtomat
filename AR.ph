#!/usr/bin/perl
# ---   *   ---   *   ---
# AR
# boiler hed

# ---   *   ---   *   ---
# sanity check

BEGIN {

  # check env
  my $root=$ENV{'ARPATH'};if(!$root) {
    print "ARPATH missing from ENV; aborted\n";
    exit;

  };

  chdir $ENV{'ARPATH'}.'/avtomat/';

# ---   *   ---   *   ---

# in: file list,src path,dst path
# check dates, update older files

sub update {

  my $ref=shift;
  my $src=shift;
  my $dst=shift;
  my $md=shift;

  for my $f(@$ref) {

    my $og=$src.$f;
    my $cp=$dst.$f;

    my $do_cp=!(-e $cp);

    $do_cp=(!$do_cp)
      ? !((-M $cp)
      <   (-M $og))

      : $do_cp;
      ;

    my @ar=split '/',$cp;
    my $basedir=join '/',@ar[0..$#ar-1];

    if(!(-e $basedir)) {
      `mkdir -p $basedir`;

    };

    if($do_cp || $md) {
      if(!$md) {`cp $og $cp`}

# ---   *   ---   *   ---

      else {

        my $ex=
          "perl -c".q{ }.

          "-I$ENV{ARPATH}/avtomat/".q{ }.
          "-I$ENV{ARPATH}/avtomat/hacks".q{ }.
          "-I$ENV{ARPATH}/avtomat/peso".q{ }.
          "-I$ENV{ARPATH}/avtomat/langdefs".q{ }.

          "-MMAM=-md".q{ }.

          "$og";

        my $out=`$ex`;

# ---   *   ---   *   ---

        my $re=qr{>>:__DEPS__:};
        my $depstr;

        if($out=~ s/>>$re//) {
          $depstr=${^CAPTURE[0]};

        } else {
          print {*STDERR} "Can't procout $og\n";

        };

# ---   *   ---   *   ---

        my $obj=$cp;
        my $pmd=$og;
        $pmd=~ s[$src][${src}/trashcan];
        $pmd.='d';

        for my $fname($obj,$pmd) {
          if(!(-e $fname)) {

            my @tmp=split m{/},$fname;
            my $path=join q{/},
              @tmp[0..$#tmp-1];

            `mkdir -p $path`;

          };
        };

# ---   *   ---   *   ---

        my $FH;
        open $FH,'+>',$obj or die "$!";
        print {$FH} $out;

        close $FH;

        open $FH,'+>',$pmd or die "$!";
        print {$FH} $depstr;

        close $FH;

# ---   *   ---   *   ---

      };

      print

        "\e[37;1m<\e[34;22mAR\e[37;1m>\e[0m ".
        "updated \e[32;1m$f\e[0m\n";

    };
  };
};

# ---   *   ---   *   ---
# check libs

  my $path=$ENV{'ARPATH'}.'/lib';
  if(! (-e $path) ) { `mkdir -p $path`; };

  update(

    [ '/MAM.pm',
      '/hacks/shwl.pm',
      '/hacks/lyfil.pm',
      '/hacks/inlining.pm',
      '/hacks/inline.pm',

      '/cli.pm',
      '/lang.pm',
      '/style.pm',
      '/arstd.pm',

      '/peso/fndmtl.pm',
      '/peso/defs.pm',

      '/peso/ops.pm',
      '/peso/type.pm',

      '/peso/rd.pm',
      '/peso/node.pm',
      '/peso/ptr.pm',
      '/peso/blk.pm',
      '/peso/sbl.pm',
      '/peso/program.pm',

      '/queue.pm',
      '/stack.pm',
      '/avt.pm'

    ],$root.'/avtomat',$path,1

  );

# ---   *   ---   *   ---
# check headers

  $path=$ENV{'ARPATH'}.'/include';
  if(! (-e $path) ) { `mkdir -p $path`; };

  update(

    [ '/AR.ph',

      '/plps/peso.lps',
      '/plps/c.lps',

    ],$root.'/avtomat',$path,0

  );

# ---   *   ---   *   ---
# this effen script...

  print `$ENV{'ARPATH'}'/avtomat/sygen'`;

};


# ---   *   ---   *   ---
1; # ret
