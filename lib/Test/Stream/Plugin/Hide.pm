package Test::Stream::Plugin::Hide;
use strict;
use warnings;

use Test::Stream::Util qw/try/;

our $VERSION = '0.000001';

my %HIDE;

# For testing
{
    no warnings 'once';
    *HIDE = sub { \%HIDE } if $Test::Stream::Plugin::Hide::TESTING;
}

# regexp for valid module name. Lifted from Module::Runtime and
# UNIVERSAL::require (modified to have anchors)
my $module_name_rx = qr/^[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*$/;

# Subs we cannot prefix with underscore, but do not want to export.
my %BAD = (
    import         => 1,
    unimport       => 1,
    load_ts_plugin => 1,
    HIDE           => 1,
);

sub load_ts_plugin {
    my $class = shift;
    my ($caller, @hide) = @_;

    my @real_hide;
    for my $hide (@hide) {
        if ($hide =~ m/^-([^_].*)$/) {
            my $name = $1;

            if ($name eq 'all') {
                my $stash = \%Test::Stream::Plugin::Hide::;
                for my $name (keys %$stash) {
                    next if $BAD{$name};
                    next if $name =~ m/^_/;
                    my $sub = $class->can($name) || next;

                    no strict 'refs';
                    *{$caller->[0] . "::$name"} = $sub;
                }
            }
            else {
                my $error = "$class does not export $name() at $caller->[1] line $caller->[2]\n";
                die $error if $BAD{$name};
                my $sub = $class->can($name) || die $error;

                no strict 'refs';
                *{$caller->[0] . "::$name"} = $sub;
            }
        }
        else {
            push @real_hide => $hide;
        }
    }
    _hide($caller, @real_hide);
}

sub import {
    my $class = shift;
    my @caller = caller;
    $class->load_ts_plugin(\@caller, @_);
}

sub unimport {
    my $class = shift;
    unhide(@_);
}

sub unhide {
    my @caller = caller;
    _unhide(\@caller, map {_mod_to_file($_, \@caller) => 1} @_);
}

sub hide {
    my @caller = caller;
    _hide(\@caller, @_);
}

sub do_hidden(&;@) {
    my ($code, @mods) = @_;

    # Copy %HIDE
    my %orig = %HIDE;
    my @caller = caller;

    my ($ok, $error) = try {
        _hide(\@caller, @mods);
        $code->();
    };

    # Unhide the new keys
    _unhide(\@caller, grep {!$orig{$_}} keys %HIDE);

    # Die if we failed, otherwise just return.
    die $error unless $ok;
    return;
}

sub _mod_to_file {
    my ($mod, $caller) = @_;

    die "'$mod' does not appear to be a valid module at $caller->[1] line $caller->[2]\n"
        unless $mod =~ $module_name_rx;

    my $file = $mod;
    $file =~ s{::}{/}g;
    $file .= '.pm';
    return $file;
}

sub _hide {
    my $caller = shift;
    for my $mod (@_) {
        my $file = _mod_to_file($mod, $caller);
        $HIDE{$file} = 1;
        next unless $INC{$file};
        die "Module '$mod' was already loaded from '$INC{$file}' before hide was requested at $caller->[1] line $caller->[2]\n";
    }
    _munge_inc();
}

sub _unhide {
    my $caller = shift;
    for my $file (@_) {
        delete $HIDE{$file};
        delete $INC{$file} unless defined $INC{$file};
    }
    _munge_inc();
}

sub _munge_inc { @INC = (\&_hook, grep { !ref($_) || $_ != \&_hook } @INC); 1 }

sub _hook {
    my ($this, $file) = @_;
    _munge_inc(); # Try to keep the hook in front.
    return unless $HIDE{$file};

    my $error = "die q|Can't locate $file in \@INC (Hidden by request)\n|;\n";
    open(my $handle, '<', \$error) || die $!;
    return $handle;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Hide - Test::Stream Plugin to hide modules for testing
purposes.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

You can use this module to hide modules from require/use. This is useful when
testing code branches that are effected by module availability.

=head1 SYNOPSIS

    use Test::Stream -V1, Hide => ['Foo::Bar', 'Baz::Bat', ...];

    like(
        dies { require Foo::Bar },
        qr/Can't locate 'Foo/Bar\.pm' in \@INC/,
        "Cannot find Foo::Bar!"
    );

    done_testing;

=head1 EXPORTS

All exports are optional, they can be requested by passing them in as argument
with the '-' prefix. You can also use '-all' to import them all. In the
L<Test::Stream> use line you can also use the '*' shortcut.

    use Test::Stream -V1, Hide => '*';

    hide 'Foo::Bar';

    ...

    do_hidden {
        hide Another::One; # Goes away at the end of the block
        ...
    } 'Baz::Bat', ...; # These are no longer hidden outside of the block

    ...

    unhide 'Foo::Bar';

    ...

    done_testing;

=over 4

=item hide 'Some::Module', 'Another::Module', ...;

Hide the specified modules.

If any modules are already loaded an exception will be thrown.

=item unhide 'Some::Module', 'Another::Module, ...;

Unhide the specified modules. If you attempted to load the modules then C<%INC>
will be cleaned so that you can try to load them again.

=item do_hidden { ... } 'Some::Module', 'Another::Module', ...;

This scopes module hides. You can list modules after the codeblock and/or you
can call C<hide()> inside the block. When the block exits all hides added
inside the scope will be unhidden.

B<Note:> C<unhide()> is NOT scoped, that means anything you unhide inside the
block will remain unhidden outside of it. You will have to re-hide anything
unhidden within. This is necessary because you generally unhide something to
then load it, you can't rehide something you loaded.

=back

=head1 SEE ALSO

=over 4

=item Devel::Hide

L<Devel::Hide>

=item Test::Without::Module

L<Test::Without::Module>

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
