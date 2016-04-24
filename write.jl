Base.writemime(io::IO, ::MIME"application/edn", value::Any) = writeEDN(io, value)

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
writeEDN(io::IO, v::Any) = writeEDN(io, v, State(ObjectIdDict(), UInt64(0)))

type State
  table::ObjectIdDict
  count::Real
end

writeEDN(io::IO, ::Void, ::State) = write(io, b"nil")
writeEDN(io::IO, str::AbstractString, ::State) = Base.print_quoted(io, str)
writeEDN(io::IO, b::Bool, ::State) = write(io, b ? b"true" : b"false")
writeEDN(io::IO, sym::Symbol, ::State) = write(io, sym)
@eval typealias Float $(symbol(:Float, WORD_SIZE))
writeEDN(io::IO, n::Union{Int,Float}, ::State) = print_shortest(io, n)
writeEDN(io::IO, n::Union{Integer,AbstractFloat}, ::State) = begin
  print(io, '#', typeof(n), " (")
  print_shortest(io, n)
  write(io, ')')
end

const special_chars = Dict('\n' => b"newline",
                           '\r' => b"return",
                           '\t' => b"tab",
                           ' '  => b"space")
writeEDN(io::IO, c::Char, ::State) = write(io, '\\', get(special_chars, c, c))

check_cache(f::Function, s::State, object, io) = begin
  if haskey(s.table, object)
    print(io, "# ", s.table[object])
  else
    s.table[object] = s.count += 1
    f()
  end
end

writeEDN(io::IO, dict::Dict, state::State) = begin
  check_cache(state, dict, io) do
    write(io, '{')
    isfirst = true
    for (key, value) in dict
      if isfirst
        isfirst = false
      else
        write(io, ' ')
      end
      writeEDN(io, key, state)
      write(io, ' ')
      writeEDN(io, value, state)
    end
    write(io, '}')
  end
end

writespaced(io::IO, itr::Any, state::State) =
  for (i, value) in enumerate(itr)
    i > 1 && write(io, ' ')
    writeEDN(io, value, state)
  end

writeEDN(io::IO, set::Set, state::State) =
  check_cache(state, set, io) do
    write(io, b"#{")
    writespaced(io, set, state)
    write(io, '}')
  end

writeEDN(io::IO, vector::Vector, state::State) =
  check_cache(state, vector, io) do
    write(io, '[')
    writespaced(io, vector, state)
    write(io, ']')
  end

writeEDN(io::IO, list::Tuple, state::State) =
  check_cache(state, list, io) do
    write(io, '(')
    writespaced(io, list, state)
    write(io, ')')
  end

writeEDN(io::IO, date::Dates.TimeType, ::State) = begin
  write(io, b"#inst \"")
  print(io, date)
  write(io, '"')
end

writeEDN(io::IO, id::Base.Random.UUID, ::State) = begin
  write(io, b"#uuid \"")
  print(io, id)
  write(io, '"')
end

"""
Maps to the tagged literal tag that should be used for a given type.
By default it will include the module the type was defined in
"""
edn_tag(value::Any) = string(typeof(value))

writeEDN(io::IO, value::Any, s::State) =
  check_cache(s, value, io) do
    print(io, '#', edn_tag(value), ' ')
    write(io, '(')
    first = true
    for field in fieldnames(value)
      if first
        first = false
      else
        write(io, ' ')
      end
      writeEDN(io, getfield(value, field), s)
    end
    write(io, ')')
  end

# Nullable needs a special case since it has a strange constructor
writeEDN(io::IO, value::Nullable, ::State) = begin
  print(io, '#', typeof(value), " (")
  isnull(value) || writeEDN(io, get(value))
  write(io, ')')
end
