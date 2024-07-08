@use "github.com/jkroso/Buffer.jl/ReadBuffer" buffer
@use "github.com/jkroso/DynamicVar.jl" @dynamic!
@use Dates

@dynamic! mod = Main

Base.parse(::MIME"application/edn", io::Any) = readEDN(io)

"""
Parse the next [edn](https://github.com/edn-format/edn) value from an `IO` stream

```julia
readEDN(stdin) # => Dict(:a=>1)
```

You can also pass an `AbstractString` as input

```julia
readEDN("{a 1}") # => Dict(:a=>1)
```
"""
readEDN(edn, m=Main) = begin
  @dynamic! let mod = m
    value = read_next(buffer(edn))
    @assert !isa(value, ClosingBrace)
    value
  end
end

const whitespace = " \t\n\r,"
const closing_braces = "]})"

struct ClosingBrace value::Char end

next_char(io::IO) = begin
  for c in readeach(io, Char)
    c ∈ whitespace || return c
  end
end

read_next(io::IO) = begin
  c = next_char(io)
  if     c == '"'  read_string(io)
  elseif c == '{'  read_dict(io)
  elseif c == '['  read_vector(io)
  elseif c == '('  read_list(io)
  elseif c == '#'  read_tagged_literal(io)
  elseif c == '\\' read_char(io)
  elseif c ∈ closing_braces; return ClosingBrace(c)
  else read_symbol(c, io) end
end

read_token(buffer::IOBuffer, io::IO) = begin
  for c in readeach(io, Char)
    c ∈ whitespace && break
    c ∈ closing_braces && (skip(io, -1); break)
    write(buffer, c)
  end
  return String(take!(buffer))
end

const number = r"^[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?$"
isnumber(str::AbstractString) = occursin(number, str)

read_symbol(c::Char, io::IO) = begin
  buf = IOBuffer()
  write(buf, c)
  str = read_token(buf, io)
  str == "true" && return true
  str == "false" && return false
  str == "nil" && return nothing
  isnumber(str) && return Meta.parse(str)
  Symbol(str)
end

const special_chars = Dict("newline" => '\n',
                           "return" => '\r',
                           "tab" => '\t',
                           "space" => ' ')

read_char(io::IO) = begin
  str = read_token(IOBuffer(), io)
  haskey(special_chars, str) && return special_chars[str]
  @assert length(str) == 1 "invalid character"
  str[1]
end

read_string(io::IO) = begin
  buf = IOBuffer()
  for c in readeach(io, Char)
    c == '"' && return String(take!(buf))
    if c == '\\'
      c = read(io, Char)
      if c == 'u' write(buf, unescape_string("\\u$(String(read(io, 4)))")[1]) # Unicode escape
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

readto(brace::ClosingBrace, io::IO) = begin
  buffer = Vector{Any}()
  while true
    value = read_next(io)
    value == brace && return buffer
    push!(buffer, value)
  end
end

read_list(io::IO) = tuple(readto(ClosingBrace(')'), io)...)
read_vector(io::IO) = readto(ClosingBrace(']'), io)

read_dict(io::IO) = begin
  dict = Dict{Any,Any}()
  while true
    key = read_next(io)
    key == ClosingBrace('}') && return dict
    dict[key] = read_next(io)
  end
end

read_tagged_literal(io::IO) = begin
  c = read(io, Char)
  c == '{' && return read_set(io)
  tag = Symbol(c, readuntil(io, ' '))
  detag(Val(tag), read_next(io))
end

read_set(io::IO) = Set(readto(ClosingBrace('}'), io))

"Takes a tag and a value and creates the native Julia type that was encoded as a tagged literal"
detag(::Val{tag}, params) where tag = eval(mod[], Meta.parse(string(tag)))(params...)
detag(::Val{:uuid}, s) = Base.UUID(parse(UInt128, "0x" * replace(s, '-'=>"")))
detag(::Val{:inst}, s) = length(s) == 10 ? Dates.Date(s, Dates.ISODateFormat) : Dates.DateTime(s, Dates.ISODateTimeFormat)
detag(::Val{:DataType}, s) = eval(mod[], Meta.parse(s))
