# Live monitor /api/lab/image POST endpoint round-trip test.
# Uses raw Sockets to avoid pulling HTTP.jl into the test deps.

using Test
using Sockets
using SpinorBEC

@testset "Live monitor /api/lab/image POST" begin
    mktempdir() do tmp
        # Set up a fake "run" dir so the endpoint accepts the POST
        run_name = "fake_run"
        run_dir = joinpath(tmp, run_name)
        mkpath(run_dir)

        # Pick a port unlikely to collide
        port = 8800 + (getpid() % 100)

        # Spawn the dashboard server in an async task
        # (the function blocks until the server is closed; we'll close it manually)
        srv_task = @async begin
            try
                # Build minimal HTML so serve_dashboard doesn't error on missing dist
                webdir = joinpath(@__DIR__, "..", "web", "dist")
                indexhtml = joinpath(webdir, "index.html")
                isfile(indexhtml) || (mkpath(webdir); write(indexhtml, "<html></html>"))
                serve_dashboard(port; base_dir=tmp)
            catch e
                e isa Base.IOError || rethrow(e)
            end
        end
        sleep(1.0)   # give the listener a moment

        # Open a TCP connection and POST a tiny "PNG" payload
        body = b"\x89PNG\r\n\x1a\n_smoke_payload_"
        sock = Sockets.connect("127.0.0.1", port)
        write(sock, "POST /api/lab/image/$(run_name) HTTP/1.1\r\n")
        write(sock, "Host: localhost:$(port)\r\n")
        write(sock, "Content-Length: $(length(body))\r\n")
        write(sock, "Content-Type: image/png\r\n")
        write(sock, "\r\n")
        write(sock, body)
        flush(sock)
        # Read the response head
        response = read(sock, String)
        close(sock)

        @test occursin("HTTP/1.1 200", response)
        @test occursin("shot_id", response)
        # File should exist
        out_dir = joinpath(run_dir, "lab_images")
        @test isdir(out_dir)
        files = readdir(out_dir)
        @test any(startswith(f, "shot_") for f in files)
        # Body bytes round-trip
        first_file = joinpath(out_dir, sort(files)[1])
        @test read(first_file) == body

        # Tear down — interrupt the server task
        try
            Base.throwto(srv_task, InterruptException())
        catch e
            # ignore
        end
    end
end

@testset "Live monitor /api/live GET endpoints" begin
    mktempdir() do tmp
        # Two runs: one "active" (recent _live_status.json), one stale (>5 min)
        active_run = "active_run"
        stale_run = "stale_run"
        mkpath(joinpath(tmp, active_run))
        mkpath(joinpath(tmp, stale_run))

        active_status = """{"step":42,"t":0.21,"energy":-1.234,"norm":1.0001,"populations":[1.0,0.0,0.0],"updated_ms":$(round(Int, time() * 1000))}"""
        write(joinpath(tmp, active_run, "_live_status.json"), active_status)
        # Make the stale file old by setting mtime to 10 min ago
        stale_path = joinpath(tmp, stale_run, "_live_status.json")
        write(
            stale_path,
            """{"step":1,"t":0.0,"energy":0.0,"norm":1.0,"populations":[1.0],"updated_ms":1}""",
        )
        old_t = time() - 600  # 10 minutes ago
        Base.Filesystem.touch(stale_path; times=(old_t, old_t))

        port = 8900 + (getpid() % 100)
        srv_task = @async begin
            try
                webdir = joinpath(@__DIR__, "..", "web", "dist")
                indexhtml = joinpath(webdir, "index.html")
                isfile(indexhtml) || (mkpath(webdir); write(indexhtml, "<html></html>"))
                serve_dashboard(port; base_dir=tmp)
            catch e
                e isa Base.IOError || rethrow(e)
            end
        end
        sleep(1.0)

        # GET /api/live/list — should contain active_run, exclude stale_run
        sock = Sockets.connect("127.0.0.1", port)
        write(sock, "GET /api/live/list HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        flush(sock)
        list_resp = read(sock, String)
        close(sock)
        @test occursin("HTTP/1.1 200", list_resp)
        @test occursin("\"$active_run\"", list_resp)
        @test !occursin("\"$stale_run\"", list_resp)

        # GET /api/live/<run> — returns the JSON file verbatim
        sock = Sockets.connect("127.0.0.1", port)
        write(
            sock,
            "GET /api/live/$(active_run) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n",
        )
        flush(sock)
        get_resp = read(sock, String)
        close(sock)
        @test occursin("HTTP/1.1 200", get_resp)
        @test occursin("\"step\":42", get_resp)
        @test occursin("\"energy\":-1.234", get_resp)

        # GET /api/live/<unknown> → 404
        sock = Sockets.connect("127.0.0.1", port)
        write(
            sock,
            "GET /api/live/no_such_run HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n",
        )
        flush(sock)
        miss_resp = read(sock, String)
        close(sock)
        @test occursin("HTTP/1.1 404", miss_resp)

        try
            Base.throwto(srv_task, InterruptException())
        catch e
        end
    end
end
