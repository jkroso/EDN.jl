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

writeEDN(value::Any) = sprint(writeEDN, value)

Base.writemime(io::IO, ::MIME"application/edn", value::Any) = writeEDN(io, value)

writeEDN(io::IO, ::Void) = write(io, b"nil")
writeEDN(io::IO, str::AbstractString) = Base.print_quoted(io, str)
writeEDN(io::IO, b::Bool) = write(io, b ? b"true" : b"false")
writeEDN(io::IO, sym::Symbol) = write(io, sym)
writeEDN(io::IO, n::Union{Integer,AbstractFloat}) = print_shortest(io, n)

const special_chars = Dict('\n' => b"newline",
                           '\r' => b"return",
                           '\t' => b"tab",
                           ' '  => b"space")
writeEDN(io::IO, c::Char) = write(io, '\\', get(special_chars, c, c))

test("primitives") do
  @test writeEDN(nothing) == "nil"
  @test writeEDN(:a) == "a"
  @test writeEDN(1) == "1"
  @test writeEDN(1.1) == "1.1"
  @test writeEDN(-1.1) == "-1.1"
  @test writeEDN(10000) == "1e4"
  @test writeEDN(true) == "true"
  @test writeEDN(false) == "false"
  @test writeEDN("ab\n") == "\"ab\\n\""
  @test writeEDN('a') == "\\a"
  @test writeEDN('\n') == "\\newline"
end

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

@test writeEDN(Dict()) == "{}"
@test writeEDN(Dict(:a=>1)) == "{a 1}"
@test writeEDN(Dict(:a=>1,true=>2)) == "{a 1 true 2}"

writespaced(io::IO, itr::Any) = begin
  isfirst = true
  for value in itr
    if isfirst
      isfirst = false
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

@test writeEDN(Set()) == "#{}"
@test writeEDN(Set([1])) == "#{1}"
@test writeEDN(Set([2,1])) == "#{2 1}"

writeEDN(io::IO, vector::Vector) = begin
  write(io, '[')
  writespaced(io, vector)
  write(io, ']')
end

@test writeEDN([]) == "[]"
@test writeEDN([1,2]) == "[1 2]"

writeEDN(io::IO, vector::Tuple) = begin
  write(io, '(')
  writespaced(io, vector)
  write(io, ')')
end

@test writeEDN(()) == "()"
@test writeEDN((1,2)) == "(1 2)"

writeEDN(io::IO, date::Dates.TimeType) = begin
  write(io, b"#inst \"")
  print(io, date)
  write(io, '"')
end

@test writeEDN(DateTime(1985,4,12,23,20,50,520)) == "#inst \"1985-04-12T23:20:50.52\""
@test writeEDN(Date(1985,4,12)) == "#inst \"1985-04-12\""

writeEDN(io::IO, id::Base.Random.UUID) = begin
  write(io, b"#uuid \"")
  print(io, id)
  write(io, '"')
end

@test writeEDN(Base.Random.UUID(UInt128(1))) == "#uuid \"00000000-0000-0000-0000-000000000001\""

writeEDN{T}(io::IO, value::T) = begin
  print(io, '#', T.name, ' ')
  writeEDN(io, map(f -> getfield(value, f), fieldnames(T)))
end

@test writeEDN(1//2) == "#Rational [1 2]"
