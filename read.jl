@require "github.com/BioJulia/BufferedStreams.jl" peek BufferedInputStream

Base.parse(::MIME"application/edn", io::Any) = readEDN(io)

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

readEDN(edn::Vector{UInt8}) = readEDN(BufferedInputStream(edn))
readEDN(edn::AbstractString) = readEDN(convert(Vector{UInt8}, edn))
readEDN(edn::IO) = begin
  value = read_next(edn, Vector{Any}())
  @assert !isa(value, ClosingBrace)
  value
end

const whitespace = b" \t\n\r,"
const numerics = b"0123456789+-"
const closing_braces = b"]})"

immutable ClosingBrace value::Char end

function read_next(io::IO, cache::Vector)
  local c
  while true
    c = read(io, UInt8)
    c ∈ whitespace && continue
    c ∈ closing_braces && return ClosingBrace(c)
    break
  end
  if     c == '"'  read_string(io)
  elseif c == '{'  read_dict(io, cache)
  elseif c == '['  read_vector(io, cache)
  elseif c == '('  read_list(io, cache)
  elseif c == '#'  read_tagged_literal(io, cache)
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

function readto(brace::ClosingBrace, io::IO, cache::Vector{Any})
  buffer = Vector{Any}()
  while true
    value = read_next(io, cache)
    value == brace && return buffer
    push!(buffer, value)
  end
end

read_list(io::IO, cache::Vector{Any}) = tuple(readto(ClosingBrace(')'), io, cache)...)
read_vector(io::IO, cache::Vector{Any}) = readto(ClosingBrace(']'), io, cache)

function read_dict(io::IO, cache::Vector{Any})
  dict = Dict{Any,Any}()
  push!(cache, dict)
  while true
    key = read_next(io, cache)
    key == ClosingBrace('}') && return dict
    dict[key] = read_next(io, cache)
  end
end

read_ref(io::IO, cache::Vector{Any}) = cache[read_next(io, cache)]

function read_tagged_literal(io::IO, cache::Vector{Any})
  c = read(io, UInt8)
  c == '{' && return read_set(io, cache)
  c == ' ' && return read_ref(io, cache)
  tag = string(Char(c), rstrip(bytestring(readuntil(io, UInt8(' ')))))
  if haskey(handlers, tag)
    handlers[tag](read_next(io, cache))
  else
    T = eval(Main, parse(tag))
    if T.mutable
      x = ccall(:jl_new_struct_uninit, Any, (Any,), T)
      push!(cache, x)
      read(io, UInt8) # (
      for f in fieldnames(T)
        setfield!(x, f, read_next(io, cache))
      end
      read(io, UInt8) # )
      x
    else
      T(read_next(io, cache)...)
    end
  end
end

read_set(io::IO, cache::Vector{Any}) = Set(readto(ClosingBrace('}'), io, cache))

const date_format = Dates.DateFormat("yyyy-mm-dd")
const datetime_format = Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.sss")

const handlers = Dict(
  "uuid" => s -> Base.Random.UUID(parse(UInt128, "0x" * replace(s, '-', ""))),
  "inst" => s -> length(s) == 10 ? Date(s, date_format) : DateTime(s, datetime_format)
)
