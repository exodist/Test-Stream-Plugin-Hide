use lib 't/lib', 'lib';
use Test::Stream -V1, Hide => '*';

imported_ok(qw{hide unhide do_hidden});

hide 'Fake::FakeA';
like(
    dies { require Fake::FakeA },
    qr{Can't locate Fake/FakeA\.pm in \@INC \(Hidden by request\)},
    "Hidden"
);
unhide 'Fake::FakeA';
ok(eval { require Fake::FakeA; 1 }, "unhidden");

like(
    dies { hide 'Fake::FakeA' },
    qr{Module 'Fake::FakeA' was already loaded from '.*' before hide was requested},
    "Cannot hide a loaded module"
);

do_hidden {
    hide 'Fake::FakeC';

    like(
        dies { require Fake::FakeB },
        qr{Can't locate Fake/FakeB\.pm in \@INC \(Hidden by request\)},
        "Hidden"
    );

    like(
        dies { require Fake::FakeC },
        qr{Can't locate Fake/FakeC\.pm in \@INC \(Hidden by request\)},
        "Hidden"
    );
} 'Fake::FakeB';

ok(eval { require Fake::FakeB; 1 }, "unhidden");
ok(eval { require Fake::FakeC; 1 }, "unhidden");

like(
    dies { do_hidden { hide "Fake::FakeD"; die "xyz" } },
    qr{xyz},
    "Exception propogated"
);
ok(eval { require Fake::FakeD; 1 }, "unhidden");

done_testing;
