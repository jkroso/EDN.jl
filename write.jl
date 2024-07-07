@use Dates: TimeType

Base.show(io::IO, ::MIME"application/edn", value::Any) = writeEDN(io, value)

"""
Maps to the tagged literal tag that should be used for a given type.
By default it will include the module the type was defined in
"""
tag(value::T) where T = tag(T)
tag(value::UnionAll) = tag(value.body)
tag(T::DataType) = begin
  length(T.parameters) == 0 && return String(T.name.name)
  "$(T.name.name){$(join(map(string, T.parameters), ','))}"
end

"""
Writes the [edn](https://github.com/edn-format/edn) representation of a
value to an `IO` stream.

```julia
writeEDN(stdout, Dict(:a=>1)) # prints "{a 1}"
```

If you do not pass an output stream then it will return an String

```julia
writeEDN(Dict(:a=>1)) # => "{a 1}"
```
"""
writeEDN(value::Any) = sprint(writeEDN, value)
writeEDN(io::IO, ::Nothing) = write(io, b"nil")
writeEDN(io::IO, str::AbstractString) = Base.print_quoted(io, str)
writeEDN(io::IO, b::Bool) = write(io, b ? "true" : "false")
writeEDN(io::IO, sym::Symbol) = write(io, sym)
writeEDN(io::IO, n::Union{Int,Float64}) = print(io, n)
writeEDN(io::IO, n::Union{Integer,AbstractFloat}) = print(io, '#', typeof(n), " (", n, ')')

const special_chars = Dict('\n' => b"newline",
                           '\r' => b"return",
                           '\t' => b"tab",
                           ' '  => b"space")

writeEDN(io::IO, c::Char) = write(io, '\\', get(special_chars, c, c))

writeEDN(io::IO, dict::Dict) = begin
  write(io, '{')
  first = true
  for (key, value) in dict
    if first
      first = false
    else
      write(io, ' ')
    end
    writeEDN(io, key)
    write(io, ' ')
    writeEDN(io, value)
  end
  write(io, '}')
end

writespaced(io::IO, itr::Any) = begin
  first = true
  for value in itr
    if first
      first = false
    else
      write(io, ' ')
    end
    writeEDN(io, value)
  end
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

writeEDN(io::IO, date::TimeType) = begin
  write(io, b"#inst \"")
  print(io, date)
  write(io, '"')
end

writeEDN(io::IO, id::Base.UUID) = begin
  write(io, b"#uuid \"")
  print(io, id)
  write(io, '"')
end

writeEDN(io::IO, value::T) where T = begin
  print(io, '#', tag(T), ' ')
  write(io, '(')
  writespaced(io, (getfield(value, field) for field in fieldnames(T)))
  write(io, ')')
end
