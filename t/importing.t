use strict;
use warnings;
use lib 't/lib', 'lib';

use Test::Stream '-V1', 'Hide' => ['Fake::FakeA'];

BEGIN {
    ok(eval {require Fake::FakeB}, "Can load FakeB");

    like(
        dies { require Fake::FakeA },
        qr{Can't locate Fake/FakeA\.pm in \@INC \(Hidden by request\)},
        "Cannot find Fake::FakeA"
    );
}
no Test::Stream::Plugin::Hide 'Fake::FakeA';
ok(eval {require Fake::FakeA}, "Can load FakeA now") || diag $@;

Test::Stream::Plugin::Hide->import('Fake::FakeC');
like(
    dies { require Fake::FakeC },
    qr{Can't locate Fake/FakeC\.pm in \@INC \(Hidden by request\)},
    "Cannot find Fake::FakeC"
);
Test::Stream::Plugin::Hide->unimport('Fake::FakeC');
ok(eval {require Fake::FakeB}, "Can load FakeC");

like(
    dies {  Test::Stream::Plugin::Hide->import('Fake::FakeA') },
    qr{Module 'Fake::FakeA' was already loaded from '.*' before hide was requested},
    "Can't hide a module once it is loaded"
);

done_testing;
