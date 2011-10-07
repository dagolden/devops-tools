#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Cwd qw/abs_path/;
use Getopt::Long;
use IPC::Cmd qw/can_run/;

#--------------------------------------------------------------------------#
# Process and validate command line options
#--------------------------------------------------------------------------#

Getopt::Long::Configure("bundling");

my $parsed_ok = GetOptions(
  'iso|i=s'     => \(my $iso),
  'mount|m=s'   => \(my $mount),
  'scratch|s=s' => \(my $scratch),
  'output|o=s'  => \(my $output),
  'src|s=s'     => \(my $src),
  'clean|c'     => \(my $clean),
  'sudo|S'      => \(my $sudo),
);

# confirm there is an ISO
die "ISO '$iso' not found\n" unless -f $iso;

# confirm we have patch files
for my $f ( qw/custom.seed autoinstall.patch/ ) {
  die "Source '$src' does not contain seed file" unless -f "$src/$f";
}

# remove trailing slashes
s{/$}{} for ( $mount, $scratch, $src );

# patch does chdir so src must be absolute
$src = abs_path($src);

#--------------------------------------------------------------------------#
# Confirm command line tools are available
#--------------------------------------------------------------------------#

my %cmd_path;

my @required_commands = qw(
  chmod
  cp
  mkdir
  mkisofs
  mount
  patch
  rm
  rsync
  umount
);

push @required_commands, 'sudo' if $sudo;

for my $cmd ( @required_commands ) {
  $cmd_path{$cmd} = can_run($cmd)
    or die "Could not find '$cmd' in PATH";
}

#--------------------------------------------------------------------------#
# Main program
#--------------------------------------------------------------------------#

say "Mounting ISO";
_system('mkdir', '-p', $mount) unless -d $mount;
_system('mount', '-o', 'loop', $iso, $mount);

say "Rsyncing ISO to scratch directory";
_system('mkdir', '-p', $scratch) unless -d $scratch;
_system('rsync', '-av', '--delete', "$iso/", $scratch);
_system('chmod', '-R', '+w', $scratch);

say "Unmounting ISO";
_system('umount', $mount);

say "Patching scratch directory";
_system("cp", "$src/custom.seed", "$scratch/preseed/custom.seed");
_system('patch','-p2','-d',$scratch,'-i',"$src/autoinstall.patch");

say "Creating new ISO";
_system('mkisofs',
  '-r','-V',"Custom Ubuntu Install CD", '-cache-inodes',
  '-J', '-l', '-b', 'isolinux/isolinux.bin', '-c', 'isolinux/boot.cat',
  '-no-emul-boot', '-boot-load-size', '4', '-boot-info-table',
  '-o', $output, $scratch
);

if ( $clean ) {
  say "Cleaning up scratch directory";
  _system('rm', '-rf', $scratch);
}

#--------------------------------------------------------------------------#
# Utility subroutines
#--------------------------------------------------------------------------#

sub _system {
  my ($cmd, @args) = @_;
  $cmd = $cmd_path{$cmd} or die "Unrecognized command '$cmd'";
  if ($sudo) {
    unshift @args, $cmd;
    $cmd = $cmd_path{sudo};
  }
  system($cmd, @args)
    and die "Error running $cmd @args" . ( $! ? "$!\n" : "\n" );
  return;
}

exit;

__END__

=head1 NAME

ubuntu-bootstrap-iso.pl - Remaster an auto-installing Ubuntu ISO

=head1 SYNOPSIS

  $ ubuntu-bootstrap-iso.pl \
    --iso /path/to/ubuntu.iso \
    --mount /mnt/iso \
    --scratch /var/tmp/bootstrap-iso \
    --src ./ubuntu-11.04-alternative-amd64 \
    --output /path/to/new.iso \
    --sudo \
    --clean

=head1 DESCRIPTION

This tool modifies a stock Ubuntu "alternate install" ISO with a custom
"preseed" file that carries out a fully-automated install sufficient to
bootstrap the chef configuration management tool.

**Caution**: This automated ISO will **DESTROY** a system it boots on
without any prompts or warnings.  Use it only on a new virtual or
bare-metal machine.

You must have permission to carry out all necessary operations.  Either
run this as root or else run it using the C<--sudo> option.

=head1 OPTIONS

=over

=item *

C<--iso PATH>: path to the stock ubuntu alternative install ISO

=item *

C<--mount PATH>: where to mount the ISO as a loopback device; will be created
if it does not exist

=item *

C<--scratch PATH>: temporary space where the new ISO will be staged; it will
be created if it does not exist; there must be enough free space to extract
the entire ISO

=item *

C<--src PATH>: path to the directory containing the F<custom.seed> and
F<autoinstall.patch> files; this may need to be specific to a particular
Ubuntu version but it's possible that files from one version will also
work on other versions, depending on how much Ubuntu has modified the
installer

=item *

C<--output PATH>: path where the new ISO will be created; it will be
destructively overwritten if it already exists

=item *

C<--sudo>: indicates that all commands need to be run using "sudo"

=item *

C<--clean>: indicates that the scratch directory should be deleted
after the new ISO is created.  If it is not deleted, subsequent runs
should rsync faster. Mount point and any intermediate directories will
not be cleaned up.

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by David Golden.
 
This is free software, licensed under The Apache License, Version 2.0, January
2004.
