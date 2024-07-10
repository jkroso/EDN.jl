@use "github.com/jkroso/Rutherford.jl/test" testset @test
@use "../write" writeEDN tag
@use Dates: DateTime, Date

testset("primitives") do
  @test writeEDN(nothing) == "nil"
  @test writeEDN(:a) == "a"
  @test writeEDN(1) == "1"
  @test writeEDN(Int8(1)) == "#Int8 (1)"
  @test writeEDN(1.1) == "1.1"
  @test writeEDN(-1.1) == "-1.1"
  @test writeEDN(10000) == "10000"
  @test writeEDN(true) == "true"
  @test writeEDN(false) == "false"
  @test writeEDN("ab\n") == "\"ab\\n\""
  @test writeEDN('a') == "\\a"
  @test writeEDN('\n') == "\\newline"
end

testset("Dict") do
  @test writeEDN(Dict()) == "{}"
  @test writeEDN(Dict(:a=>1)) == "{a 1}"
  @test writeEDN(Dict(:a=>1,true=>2)) == "{a 1 true 2}"
end

@test writeEDN(Set()) == "#{}"
@test writeEDN(Set([1])) == "#{1}"
@test writeEDN(Set([2,1])) == "#{2 1}"

@test writeEDN([]) == "[]"
@test writeEDN([1,2]) == "[1 2]"

@test writeEDN(()) == "()"
@test writeEDN((1,2)) == "(1 2)"

@test writeEDN(DateTime(1985,4,12,23,20,50,520)) == "#inst \"1985-04-12T23:20:50.520\""
@test writeEDN(Date(1985,4,12)) == "#inst \"1985-04-12\""

@test writeEDN(Base.UUID(UInt128(1))) == "#uuid \"00000000-0000-0000-0000-000000000001\""

@test writeEDN(1//2) == "#Rational{Int64} (1 2)"

struct A a end
struct B{t} a end
struct C{t,d} a end

testset("composite types") do
  @test writeEDN(A(1)) == "#A (1)"
  @test writeEDN(B{Int64}(1)) == "#B{Int64} (1)"
  @test writeEDN(B{:a}(1)) == "#B{:a} (1)"
end

testset("DataTypes") do
  @test writeEDN(Rational{Int64}) == "#Type \"Rational{Int64}\""
  @test writeEDN(B{:a}) == "#Type \"B{:a}\""
  @test writeEDN(C{:a, 1}) == "#Type \"C{:a,1}\""
end

@enum Fruit apple=1 orange=2 kiwi=3

testset("Enum") do
  @test writeEDN(apple) == "#Fruit (1)"
  @test writeEDN(orange) == "#Fruit (2)"
end
