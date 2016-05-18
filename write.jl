Base.writemime(io::IO, ::MIME"application/edn", value::Any) = writeEDN(io, value)

"""
Maps to the tagged literal tag that should be used for a given type.
By default it will include the module the type was defined in
"""
edn_tag(value::Any) = string(typeof(value))

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

writeEDN(io::IO, ::Void) = write(io, b"nil")
writeEDN(io::IO, str::AbstractString) = Base.print_quoted(io, str)
writeEDN(io::IO, b::Bool) = write(io, b ? b"true" : b"false")
writeEDN(io::IO, sym::Symbol) = write(io, sym)
@eval typealias Float $(symbol(:Float, WORD_SIZE))
writeEDN(io::IO, n::Union{Int,Float}) = print_shortest(io, n)
writeEDN(io::IO, n::Union{Integer,AbstractFloat}) = begin
  print(io, '#', typeof(n), " (")
  print_shortest(io, n)
  write(io, ')')
end

const special_chars = Dict('\n' => b"newline",
                           '\r' => b"return",
                           '\t' => b"tab",
                           ' '  => b"space")
writeEDN(io::IO, c::Char) = write(io, '\\', get(special_chars, c, c))

writeEDN(io::IO, dict::Dict) = begin
  write(io, '{')
  isfirst = true
  for (key, value) in dict
    if isfirst
      isfirst = false
    else
      write(io, ' ')
    end
    writeEDN(io, key)
    write(io, ' ')
    writeEDN(io, value)
  end
  write(io, '}')
end

writespaced(io::IO, itr::Any) =
  for (i, value) in enumerate(itr)
    i > 1 && write(io, ' ')
    writeEDN(io, value)
  end

writeEDN(io::IO, set::Set) = begin
  write(io, b"#{")
  writespaced(io, set)
  write(io, '}')
end

writeEDN(io::IO, vector::Vector) = begin
  write(io, '[')
  writespaced(io, vector)
  write(io, ']')
end

writeEDN(io::IO, list::Tuple) = begin
  write(io, '(')
  writespaced(io, list)
  write(io, ')')
end

writeEDN(io::IO, date::Dates.TimeType) = begin
  write(io, b"#inst \"")
  print(io, date)
  write(io, '"')
end

writeEDN(io::IO, id::Base.Random.UUID) = begin
  write(io, b"#uuid \"")
  print(io, id)
  write(io, '"')
end

writeEDN(io::IO, value::Any) = begin
  print(io, '#', edn_tag(value), ' ')
  write(io, '(')
  first = true
  for field in fieldnames(value)
    if first
      first = false
    else
      write(io, ' ')
    end
    writeEDN(io, getfield(value, field))
  end
  write(io, ')')
end

# Nullable needs a special case since it has a strange constructor
writeEDN(io::IO, value::Nullable) = begin
  print(io, '#', typeof(value), " (")
  isnull(value) || writeEDN(io, get(value))
  write(io, ')')
end
