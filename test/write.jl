@require "../write" writeEDN edn_tag

test("primitives") do
  @test writeEDN(nothing) == "nil"
  @test writeEDN(:a) == "a"
  @test writeEDN(1) == "1"
  @test writeEDN(Int8(1)) == "#Int8 (1)"
  @test writeEDN(1.1) == "1.1"
  @test writeEDN(-1.1) == "-1.1"
  @test writeEDN(10000) == "1e4"
  @test writeEDN(true) == "true"
  @test writeEDN(false) == "false"
  @test writeEDN("ab\n") == "\"ab\\n\""
  @test writeEDN('a') == "\\a"
  @test writeEDN('\n') == "\\newline"
end

test("Dict") do
  @test writeEDN(Dict()) == "{}"
  @test writeEDN(Dict(:a=>1)) == "{a 1}"
  @test writeEDN(Dict(:a=>1,true=>2)) == "{a 1 true 2}"
  a = Dict()
  a[:self] = a
  @test writeEDN(a) == "{self # 1}"
end

@test writeEDN(Set()) == "#{}"
@test writeEDN(Set([1])) == "#{1}"
@test writeEDN(Set([2,1])) == "#{2 1}"

@test writeEDN([]) == "[]"
@test writeEDN([1,2]) == "[1 2]"

@test writeEDN(()) == "()"
@test writeEDN((1,2)) == "(1 2)"

@test writeEDN(DateTime(1985,4,12,23,20,50,520)) == "#inst \"1985-04-12T23:20:50.52\""
@test writeEDN(Date(1985,4,12)) == "#inst \"1985-04-12\""

@test writeEDN(Base.Random.UUID(UInt128(1))) == "#uuid \"00000000-0000-0000-0000-000000000001\""

@test writeEDN(1//2) == "#Rational{Int64} (1 2)"
@test writeEDN(Nullable{Int32}(Int32(1))) == "#Nullable{Int32} (#Int32 (1))"
@test writeEDN(Nullable{Int32}()) == "#Nullable{Int32} ()"

type A val end
type B
  self
  B() = (b=new(); b.self=b)
end
edn_tag(::A) = "A"
edn_tag(::B) = "B"

test("composite types") do
  @test writeEDN(B()) == "#B (# 1)"
  a = A(1)
  c = A(a)
  b = A(c)
  @test writeEDN([a,b,c]) == "[#A (1) #A (#A (# 2)) # 4]"
end
