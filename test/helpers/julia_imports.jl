"""External package roots in Julia syntax, excluding comments and string data."""
function julia_import_roots(source::AbstractString)
    roots = Set{String}()
    function visit(node)
        node isa Expr || return nothing
        if node.head in (:using, :import)
            for arg in node.args
                path = arg isa Expr && arg.head === Symbol(":") ? arg.args[1] : arg
                path isa Expr && path.head === :. || continue
                root = first(path.args)
                root isa Symbol && root !== :. && push!(roots, string(root))
            end
        else
            foreach(visit, node.args)
        end
    end
    visit(Meta.parseall(source))
    roots
end
