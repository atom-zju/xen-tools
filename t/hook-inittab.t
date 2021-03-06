#!perl -w
#
#  Test that the /etc/inittab file is modified as we expect.
#
# Steve
# --
#

use strict;
use Test::More;
use File::Temp;
use File::Copy;

my $example_inittab = 't/data/inittab';
my $hook_dir = $ENV{AS_INSTALLED_TESTING} ? '/usr/share/xen-tools' : 'hooks';

#
#  Check if example inittab is present, else bail out
#
if (-e $example_inittab) {
    #
    #  Rather than having a hardwired list of distributions to test
    # against we look for subdirectories beneath hooks/ and test each
    # one.
    #
    foreach my $dir ( glob( "$hook_dir/*" ) )
    {
        next if ( $dir =~ /CVS/i );
        next if ( $dir =~ /common/i );
        next if ( ! -d $dir );

        if ( $dir =~ /$hook_dir\/(.*)/ )
        {
            my $dist = $1;

            next if ( $dist =~ /(edgy|dapper|ubuntu)/i );

            testHook( $dist );
        }
    }
} else {
    BAIL_OUT("$example_inittab not found, source distribution seems incomplete");
}

done_testing();

sub testHook
{
    my ( $dist ) = ( @_ );

    #
    #  Create a temporary directory, and copy our inittab into it.
    #
    my $dir        = File::Temp::tempdir( CLEANUP => 1 );
    mkdir( $dir . "/etc", 0777 );
    File::Copy::cp( $example_inittab, $dir . "/etc" );

    #
    # Make sure that worked.
    #
    ok( -d $dir, "Temporary directory created OK" );
    ok( -e $dir . "/etc/inittab", "/etc/inittab copied correctly." );

    ok( -e "$hook_dir/$dist/30-disable-gettys", "$dist inittab fixing hook exists" );
    ok( -x "$hook_dir/$dist/30-disable-gettys", "$dist inittab fixing hook is executable" );

    #
    #  Call the hook
    #
    `$hook_dir/$dist/30-disable-gettys $dir`;

    #
    #  Now we read the new file, and make sure it looks like we expect.
    #
    open( INIT, "<", $dir . "/etc/inittab" )
      or die "Failed to open modified inittab.";
    my @lines = <INIT>;
    close( INIT );

    #
    # Test we read some lines.
    #
    ok( $#lines > 0, "We read the new inittab." );

    #
    # Now test that the lines look like they should.
    #
    my $count = 0;
    foreach my $line ( @lines )
    {
        if ( $line =~ /^([1-9])(.*) (.*)$/ )
        {
            #
            # This should be our only line:
            #
            #  1:2345:respawn:/sbin/getty 38400 console
            #
            ok( $1 eq "1", "We found the first getty line." );
            ok( $3 eq "hvc0", "Which does uses the correct driver: $3" );
        }

        if ( $line =~ /^(.).*getty/ )
        {
            $count += 1 if ( $1 ne "#" );
        }
    }

    ok( $count = 1, "Only found one uncommented getty line" );
}
