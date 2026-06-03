#!/usr/bin/perl
# ---   *   ---   *   ---
# NBUILD
# xclip machine
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# NOTE
#
# nbuild does copy and paste of files
# to the clipboard, and supports '#include'
# style directives... which *kind* of makes
# it viable for building simple projects,
# as you can put multiple files together...
#
# ... but it is still not *quite* a build tool,
#     hence the name ;>

# ---   *   ---   *   ---
# deps

package avto::nbuild;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Cli;

  use Arstd::String qw(gsplit wstrip);
  use Arstd::Array qw(iof);
  use Arstd::Bin qw(orc owc xclip);
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::pproc;
  use Arstd::throw;

  # remember to add supported filetypes here!!
  use Ftype;
  use Ftype::Text::C;
  use Ftype::Text::JS;
  use Ftype::Text::HTML;


# ---   *   ---   *   ---
# options avail to CLI

sub cli_opts {
  return (
    { id    => 'regex',
      short => '-r',
      long  => '--regex',
      argc  => 1

    },{
      id    => 'strip',
      short => '-s',
      long  => '--strip',
      argc  => 0

    },{
      id    => 'nocom',
      short => '-nc',
      long  => '--no-comment',
      argc  => 0

    # enable '#include' style directives
    },{
      id    => 'pproc',
      short => '-p',
      long  => '--pproc',
      argc  => 0

    # put the resulting code in it's own scope
    },{
      id    => 'wrap',
      short => '-w',
      long  => '--wrap',
      argc  => 0

    # write to a file instead of the clipboard ;>
    },{
      id    => 'output',
      short => '-o',
      long  => '--output',
      argc  => 1

    },{
      id    => 'inplace',
      short => '-i',
      long  => '--inplace',
      argc  => 0,
      combo => [qw(+pproc)]

    # combination flags for convenience
    },{
      id    => 'build',
      short => '-b',
      long  => '--build',
      argc  => 1,
      combo => [qw(+pproc +output)]
    },{
      id    => 'test',
      short => '-t',
      long  => '--test',
      argc  => 0,
      combo => [qw(+pproc +wrap)]
    },
  );
};


# ---   *   ---   *   ---
# reads CLI args

sub cli_rd {
  my $cli=Cli->new(cli_opts());
  my @rem=$cli->take(@_);

  cli_proc($cli);
  return ($cli,@rem);
};
sub cli_proc {
  my ($cli)=@_;

  if($cli->{regex}) {
    $cli->{re}=qr"^$cli->{re}:?\s*"x;
  };
  return;
};


# ---   *   ---   *   ---
# entry point

sub import {
  my $class=shift;

  # read arguments
  my ($cli,@file)=cli_rd(@_);
  throw "No files to copy" if ! @file;

  # get contents of all files
  my $body=join "\n",map {
    file_rd($cli,$ARG);

  } @file;

  # ^dump to output file?
  if(! is_null($cli->{output})) {
    return owc($cli->{output},$body);

  # ^give result back to caller?
  } elsif($cli->{inplace}) {
    return $body;
  };
  # ^nope, write to clipboard!
  return xclip($body);
};


# ---   *   ---   *   ---
# handles individual file

sub file_rd {
  # read the file
  my ($cli,$fpath)=@_;
  my $body=orc($fpath);

  # tokenize in-the-way things like strings
  # and comments and what not
  #
  # we use `strtok_syx()` from the associated
  # filetype definitions, if any are available
  #
  # else the default ones are used
  # (defined by Arstd::strtok)
  my ($lang,$syx)=Arstd::pproc::get_lang(
    Ftype::from_ext($fpath),
    pproc =>  $cli->{pproc},
    com   =>! $cli->{nocom},
  );
  my $strar=[];
  strtok($strar,$body,syx=>$syx);

  # use only specific lines?
  if($cli->{regex}) {
    $body=join "\n",(
      grep  {$ARG=~ s[$cli->{regex}][]}
      split (qr"\n",$body)
    );
  };
  # apply standard preprocessor?
  if($cli->{pproc}) {
    pproc($strar,$body,lang=>$lang);
  };
  # strip file?
  if($cli->{clean}) {
    $body=join "\n",gsplit($body,qr"\n+");
    wstrip($body);
  };
  # put the result in it's own scope?
  #
  # TODO do this in a language-sensitive way,
  #      it doesn't matter right now
  if($cli->{wrap}) {
    $body="{\n$body\n};\n";
  };
  # untokenize and give
  unstrtok($body,$strar);
  return $body;
};


# ---   *   ---   *   ---
1; # ret
