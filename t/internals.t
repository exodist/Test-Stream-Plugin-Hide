BEGIN { $Test::Stream::Plugin::Hide::TESTING = 1 }
use lib 't/lib', 'lib';
use Test::Stream -V1, Hide => ['Fake::FakeA', 'Fake::FakeB', '-all'];

my $hide = Test::Stream::Plugin::Hide->HIDE;
is(
    $hide,
    { 'Fake/FakeA.pm' => 1, 'Fake/FakeB.pm' => 1 },
    "Hid FakeA and FakeB"
);

unhide('Fake::FakeB');
is(
    $hide,
    { 'Fake/FakeA.pm' => 1 },
    "Unhid FakeB"
);

hide('Fake::FakeC');
is(
    $hide,
    { 'Fake/FakeA.pm' => 1, 'Fake/FakeC.pm' => 1 },
    "Hid FakeC"
);

unshift @INC => 'FAKEFAKEFAKE';
unhide('Fake::FakeC');
ref_is($INC[0], Test::Stream::Plugin::Hide->can('_hook'), "Hook is number 1");
is($INC[1], 'FAKEFAKEFAKE', "FAKEFAKEFAKE was taken down a notch");

%$hide = ();

is($hide, {}, "nothing to hide");
do_hidden {
    is($hide, {'Fake/FakeA.pm' => 1}, "Hid by arg");
    hide('Fake::FakeB');
    is($hide, {'Fake/FakeA.pm' => 1, 'Fake/FakeB.pm' => 1}, "Hid inside");
} 'Fake::FakeA';
is($hide, {}, "nothing to hide");

BEGIN { *mod_to_file = Test::Stream::Plugin::Hide->can('_mod_to_file') }

is(mod_to_file('xxx'), 'xxx.pm', "simple module to file");
is(mod_to_file('xxx::yyy'), 'xxx/yyy.pm', "2 part module to file");
is(mod_to_file('xxx::yyy::zzz'), 'xxx/yyy/zzz.pm', "3 part module to file");

like(
    dies { mod_to_file('123:123', ['A', 'A.pm', 42]) },
    qr/'123:123' does not appear to be a valid module at A\.pm line 42/,
    "module name must be valid"
);

like(
    dies { mod_to_file('foo/bar.pm', ['A', 'A.pm', 42]) },
    qr{'foo/bar\.pm' does not appear to be a valid module at A\.pm line 42},
    "module name must not be a file already"
);

done_testing;
