# EDN.jl

Provides support for the [EDN](https://github.com/edn-format/edn) format. Which stands for extensible data notation. It turns out to be particularly awesome in Julia because you don't need to make any effort to support custom types. Though if the EDN data was generated by another language you probably still will have to register tagged literal handlers manually.

```Julia
@use "github.com/jkroso/EDN.jl" ["read" readEDN untag] ["write" writeEDN tag]

writeEDN(1//2) == "#Rational{Int64} (1 2)"
readEDN("#Rational{Int64} (1 2)") == 1//2
```

Custom types work automatically though we do have to pass in the module its defined in when reading the EDN data back into memory

```julia
struct CustomType
  a
  b
end

writeEDN(CustomType(1,2)) == "#CustomType (1 2)"
readEDN("#CustomType (1 2)", @__MODULE__) == CustomType(1,2)
```
