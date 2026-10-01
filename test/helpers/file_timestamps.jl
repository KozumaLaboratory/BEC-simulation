"""Set fixture timestamps on Windows and Unix without coreutils."""
function set_test_mtime!(path, epoch=1_700_000_000)
    python = Sys.iswindows() ? "python" : "python3"
    run(
        `$python -c "import os, sys; t=float(sys.argv[2]); os.utime(sys.argv[1], (t, t))" $path $epoch`
    )
    return path
end
