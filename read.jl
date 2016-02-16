@require "github.com/BioJulia/BufferedStreams.jl" peek BufferedInputStream

"""
Parse the next [edn](https://github.com/edn-format/edn) value from an `IO` stream

```julia
readEDN(STDIN) # => Dict(:a=>1)
```

You can also pass an `AbstractString` as input

```julia
readEDN("{a 1}") # => Dict(:a=>1)
```
"""
function readEDN end

Base.parse(::MIME"application/edn", io::Any) = readEDN(io)

readEDN(edn::Vector{UInt8}) = readEDN(BufferedInputStream(edn))
readEDN(edn::AbstractString) = readEDN(convert(Vector{UInt8}, edn))
readEDN(edn::IO) = begin
  value = read_next(edn)
  @assert !isa(value, ClosingBrace)
  value
end

const whitespace = b" \t\n\r,"
const numerics = b"0123456789+-"
const closing_braces = b"]})"

immutable ClosingBrace value::Char end

function read_next(io::IO)
  local c
  while true
    c = read(io, UInt8)
    c ∈ whitespace && continue
    c ∈ closing_braces && return ClosingBrace(c)
    break
  end
  if     c == '"'  read_string(io)
  elseif c == '{'  read_dict(io)
  elseif c == '['  read_vector(io)
  elseif c == '('  read_list(io)
  elseif c == '#'  read_tagged_literal(io)
  elseif c == '\\' read_char(io)
  else             read_symbol(c, io) end
end

function buffer_chars(buffer::Vector{UInt8}, io::IO)
  while !eof(io)
    c = peek(io)
    c ∈ whitespace && break
    c ∈ closing_braces && break
    push!(buffer, read(io, UInt8))
  end
  return buffer
end

const number = r"^[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?$"
isnumber(str::AbstractString) = ismatch(number, str)

function read_symbol(c::UInt8, io::IO)
  str = bytestring(buffer_chars([c], io))
  if     str == "true"  true
  elseif str == "false" false
  elseif str == "nil"   nothing
  elseif isnumber(str)  parse(str)
  else                  symbol(str) end
end

const special_chars = Dict(b"newline" => '\n',
                           b"return" => '\r',
                           b"tab" => '\t',
                           b"space" => ' ')
function read_char(io::IO)
  buffer = buffer_chars(UInt8[], io)
  haskey(special_chars, buffer) && return special_chars[buffer]
  @assert length(buffer) == 1 "invalid character"
  return Char(buffer[1])
end

test("primitives") do
  @test readEDN("false") == false
  @test readEDN("true") == true
  @test readEDN("nil") == nothing
  @test readEDN("1") == 1
  @test readEDN("1.1") == 1.1
  @test readEDN("-1.1e3") == -1.1e3
  @test readEDN("\\newline") == '\n'
  @test readEDN("\\c") == '\c'
  @test readEDN("c") == symbol("c")
  @test readEDN(":c") == symbol(":c")
  @test readEDN(":c/b") == symbol(":c/b")
end

function read_string(io::IO)
  buf = IOBuffer()
  while true
    c = read(io, UInt8)
    c == '"' && return takebuf_string(buf)
    if c == '\\'
      c = read(io, UInt8)
      if c == 'u' write(buf, unescape_string("\\u$(utf8(readbytes(io, 4)))")[1]) # Unicode escape
      elseif c == '"'  write(buf, '"' )
      elseif c == '\\' write(buf, '\\')
      elseif c == '/'  write(buf, '/' )
      elseif c == 'b'  write(buf, '\b')
      elseif c == 'f'  write(buf, '\f')
      elseif c == 'n'  write(buf, '\n')
      elseif c == 'r'  write(buf, '\r')
      elseif c == 't'  write(buf, '\t')
      else error("Unrecognized escaped character: $(convert(Char, c))") end
    else
      write(buf, c)
    end
  end
end

test("strings") do
  @test readEDN("\"hi\"") == "hi"
  @test readEDN("\"\\n\"") == "\n"
  @test readEDN("\"\\u2208\"") == "∈"
end

function readuntil(brace::ClosingBrace, io::IO)
  buffer = Any[]
  while true
    value = read_next(io)
    value == brace && return buffer
    push!(buffer, value)
  end
end

read_list(io::IO) = tuple(readuntil(ClosingBrace(')'), io)...)

test("List") do
  @test readEDN("()") == ()
  @test readEDN("(1)") == (1,)
  @test readEDN("(1 2)") == (1,2)
  @test readEDN("( 1, 2 )") == (1,2)
end

read_vector(io::IO) = readuntil(ClosingBrace(']'), io)

test("Vector") do
  @test readEDN("[]") == []
  @test readEDN("[1]") == Any[1]
  @test readEDN("[1,2]") == Any[1,2]
  @test readEDN("[ 1, 2 ]") == Any[1,2]
end

function read_dict(io::IO)
  dict = Dict{Any,Any}()
  while true
    key = read_next(io)
    key == ClosingBrace('}') && return dict
    dict[key] = read_next(io)
  end
end

test("Dict") do
  @test readEDN("{}") == Dict()
  @test readEDN("{a 1}") == Dict(:a=>1)
  @test readEDN("{ a 1 }") == Dict(:a=>1)
  @test readEDN("{a 1 b 2}") == Dict(:a=>1,:b=>2)
end

function read_tagged_literal(io::IO)
  c = read(io, UInt8)
  c == '{' && return read_set(io)
  tag = symbol(buffer_chars(UInt8[c], io))
  value = readEDN(io)
  if haskey(handlers, tag)
    handlers[tag](value)
  else
    eval(Main, tag)(value...)
  end
end

read_set(io) = Set(readuntil(ClosingBrace('}'), io))

const date_format = Dates.DateFormat("yyyy-mm-dd")
const datetime_format = Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.sss")

const handlers = Dict(
  :uuid => s -> Base.Random.UUID(parse(UInt128, "0x" * replace(s, '-', ""))),
  :inst => s -> length(s) == 10 ? Date(s, date_format) : DateTime(s, datetime_format)
)

test("tagged literals") do
  @test readEDN("#uuid \"00000000-0000-0000-0000-000000000001\"") == Base.Random.UUID(UInt128(1))
  @test readEDN("#inst \"1985-04-12T23:20:50.52\"") == DateTime(1985,4,12,23,20,50,520)
  @test readEDN("#inst \"1985-04-12\"") == Date(1985,4,12)
  @test readEDN("#{}") == Set()
  @test readEDN("#{1 2}") == Set([1,2])
  @test readEDN("#Rational [1 2]") == 1//2
end
