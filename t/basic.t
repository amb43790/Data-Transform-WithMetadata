use strict;
use warnings;

use Data::Transform::WithMetadata qw(encode decode);

use Scalar::Util;
use Test::More tests => 21;

test_scalar();
test_simple_references();
test_filehandle();
test_coderef();
test_refref();

sub test_scalar {
    my $tester = sub {
        my($original, $desc) = @_;
        my $encoded = encode($original);
        is($encoded, $original, "encode $desc");
        my $decoded = decode($encoded);
        is($decoded, $original, "decode $desc");
    };

    $tester->(1, 'number');
    $tester->('a string', 'string');
    $tester->('', 'empty string');
    $tester->(undef, 'undef');
}

sub test_simple_references {
    my %tests = (
        scalar => \'a scalar',
        array  => [ 1,2,3 ],
        hash   => { one => 1, two => 2, string => 'a string' }
    );
    foreach my $test ( keys %tests ) {
        my $original = $tests{$test};
        my $encoded = encode($original);

        my $expected = {
            __value => ref($original) eq 'SCALAR' ? $$original : $original,
            __reftype => Scalar::Util::reftype($original),
            __refaddr => Scalar::Util::refaddr($original),
        };
        $expected->{__blesstype} = Scalar::Util::blessed($original) if Scalar::Util::blessed($original);

        is_deeply($encoded, $expected, "encode $test");

        my $decoded = decode($encoded);
        is_deeply($decoded, $original, "decode $test");
    }
}

sub test_filehandle {
    open(my $filehandle, __FILE__) || die "Can't open file: $!";

    my $encoded = encode($filehandle);
    my $decoded = decode($encoded);

    ok(delete $encoded->{__value}->{SCALAR}->{__refaddr},
        'anoymous scalar has __refaddr');

    my $expected = {
        __value => {
            IO => fileno($filehandle),
            SCALAR => {
                __value => undef,
                __reftype => 'SCALAR',
            },
        },
        __reftype => 'GLOB',
        __refaddr => Scalar::Util::refaddr($filehandle),
    };

    is_deeply($encoded, $expected, 'encode filehandle');

    is(fileno($decoded), fileno($filehandle), 'decode filehandle');
}

sub test_coderef {
    my $original = sub { 1 };

    my $encoded = encode($original);

    my $expected = {
        __value => "$original",
        __reftype => 'CODE',
        __refaddr => Scalar::Util::refaddr($original),
    };

    is_deeply($encoded, $expected, 'encode coderef');

    my $decoded = decode($encoded);
    is(ref($decoded), 'CODE', 'decoded to a coderef');
}

sub test_refref {
    my $hash = { };
    my $original = \$hash;

    my $expected = {
        __reftype => 'REF',
        __refaddr => Scalar::Util::refaddr($original),
        __value => {
            __reftype => 'HASH',
            __refaddr => Scalar::Util::refaddr($hash),
            __value => { }
        }
    };
    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode ref reference');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode ref reference');
}
