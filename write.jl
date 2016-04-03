Base.writemime(io::IO, ::MIME"application/edn", value::Any) = writeEDN(io, value)

"""
Produces a globably unique integer for an entity; similar to object_id
but in this case two objects can return the same number without being
the same object in memory
"""
function entity_id end

"""
Writes the [edn](https://github.com/edn-format/edn) representation of a
value to an `IO` stream.

```julia
writeEDN(STDOUT, Dict(:a=>1)) # prints "{a 1}"
```

If you do not pass an output stream then it will return an ASCIIString

```julia
writeEDN(Dict(:a=>1)) # => "{a 1}"
```
"""
function writeEDN end

# to string
writeEDN(value::Any) = sprint(writeEDN, value)
# create cache
writeEDN(io::IO, v::Any) = writeEDN(io, v, ([], Dict{Integer,Vector{Any}}()))

writeEDN(io::IO, ::Void, ::Tuple) = write(io, b"nil")
writeEDN(io::IO, str::AbstractString, ::Tuple) = Base.print_quoted(io, str)
writeEDN(io::IO, b::Bool, ::Tuple) = write(io, b ? b"true" : b"false")
writeEDN(io::IO, sym::Symbol, ::Tuple) = write(io, sym)
@eval typealias Float $(symbol(:Float, WORD_SIZE))
writeEDN(io::IO, n::Union{Int,Float}, ::Tuple) = print_shortest(io, n)
writeEDN(io::IO, n::Union{Integer,AbstractFloat}, ::Tuple) = begin
  print(io, '#', typeof(n), " [")
  print_shortest(io, n)
  write(io, ']')
end

const special_chars = Dict('\n' => b"newline",
                           '\r' => b"return",
                           '\t' => b"tab",
                           ' '  => b"space")
writeEDN(io::IO, c::Char, ::Tuple) = write(io, '\\', get(special_chars, c, c))

check_cache(f, state, object, io) = begin
  path, cache = state
  id = entity_id(object)
  if haskey(cache, id)
    write(io, "#ref ")
    writeEDN(io, cache[id])
  else
    cache[id] = path
    f()
  end
end

writeEDN(io::IO, dict::Dict, state::Tuple) = begin
  path, cache = state
  check_cache(state, dict, io) do
    write(io, '{')
    isfirst = true
    for (key, value) in dict
      if isfirst
        isfirst = false
      else
        write(io, ' ')
      end
      substate = (vcat(path, key), cache)
      writeEDN(io, key, substate)
      write(io, ' ')
      writeEDN(io, value, substate)
    end
    write(io, '}')
  end
end

writespaced(io::IO, itr::Any, state::Tuple) = begin
  path, cache = state
  for (i, value) in enumerate(itr)
    i > 1 && write(io, ' ')
    writeEDN(io, value, (vcat(path, i), cache))
  end
end

writeEDN(io::IO, set::Set, state::Tuple) =
  check_cache(state, set, io) do
    write(io, b"#{")
    writespaced(io, set, state)
    write(io, '}')
  end

writeEDN(io::IO, vector::Vector, state::Tuple) =
  check_cache(state, vector, io) do
    write(io, '[')
    writespaced(io, vector, state)
    write(io, ']')
  end

writeEDN(io::IO, list::Tuple, state::Tuple) =
  check_cache(state, list, io) do
    write(io, '(')
    writespaced(io, list, state)
    write(io, ')')
  end

writeEDN(io::IO, date::Dates.TimeType, ::Tuple) = begin
  write(io, b"#inst \"")
  print(io, date)
  write(io, '"')
end

writeEDN(io::IO, id::Base.Random.UUID, ::Tuple) = begin
  write(io, b"#uuid \"")
  print(io, id)
  write(io, '"')
end

"""
Maps to the tagged literal tag that should be used for a given type.
By default it will include the module the type was defined in
"""
edn_tag(value::Any) = string(typeof(value))

writeEDN(io::IO, value::Any, state::Tuple) = begin
  check_cache(state, value, io) do
    print(io, '#', edn_tag(value), ' ')
    writeEDN(io, map(f -> getfield(value, f), fieldnames(value)), state)
  end
end

# Nullable needs a special case since it has a strange constructor
writeEDN(io::IO, value::Nullable, ::Tuple) = begin
  print(io, '#', typeof(value), " [")
  isnull(value) || writeEDN(io, get(value))
  write(io, ']')
end
