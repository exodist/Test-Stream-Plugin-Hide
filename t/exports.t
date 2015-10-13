use Test::Stream -V1, 'Hide';

not_imported_ok(qw{
    import unimport load_ts_plugin
    _mod_to_file _hide _unhide _munge_inc _hook
    HIDE
    hide unhide do_hidden
});

{
    package Test::All;
    use Test::Stream -V1, Hide => '*';

    imported_ok(qw{hide unhide do_hidden});

    not_imported_ok(qw{
        import unimport load_ts_plugin
        _mod_to_file _hide _unhide _munge_inc _hook
        HIDE
    });
}

{
    package Test::Some;

    use Test::Stream -V1, Hide => [qw/-hide -unhide/];

    imported_ok(qw{hide unhide});

    not_imported_ok(qw{
        import unimport load_ts_plugin
        _mod_to_file _hide _unhide _munge_inc _hook
        do_hidden
        HIDE
    });
}

like(
    dies { Test::Stream::Plugin::Hide->import("-$_") },
    qr/Test::Stream::Plugin::Hide does not export $_\(\)/,
    "Cannot import $_"
) for qw/import unimport HIDE load_ts_plugin xxx yyy/;

done_testing;
