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
