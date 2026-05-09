# Dashboard JSON serialisation helpers

function _write_json(io::IO, d::Dict)
    print(io, "{")
    first_entry = true
    for (k, v) in d
        first_entry || print(io, ",")
        first_entry = false
        _write_json(io, k)
        print(io, ":")
        _write_json(io, v)
    end
    print(io, "}")
end

function _write_json(io::IO, v::AbstractVector)
    print(io, "[")
    for (i, x) in enumerate(v)
        i > 1 && print(io, ",")
        _write_json(io, x)
    end
    print(io, "]")
end

function _write_json(io::IO, s::AbstractString)
    print(io, '"')
    for ch in s
        if ch == '"'
            print(io, "\\\"")
        elseif ch == '\\'
            print(io, "\\\\")
        elseif ch == '\n'
            print(io, "\\n")
        elseif ch == '\r'
            print(io, "\\r")
        elseif ch == '\t'
            print(io, "\\t")
        elseif codepoint(ch) < 0x20
            @printf(io, "\\u%04x", codepoint(ch))
        else
            print(io, ch)
        end
    end
    print(io, '"')
end
_write_json(io::IO, n::Real) =
    if isnan(n)
        print(io, "null")
    elseif isinf(n)
        print(io, "null")
    else
        print(io, n)
    end
_write_json(io::IO, b::Bool) = print(io, b ? "true" : "false")
_write_json(io::IO, ::Nothing) = print(io, "null")

function _json_string(data)
    buf = IOBuffer()
    _write_json(buf, data)
    String(take!(buf))
end

