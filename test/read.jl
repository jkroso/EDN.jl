@use "github.com/jkroso/Rutherford.jl/test" testset @test
@use Dates: DateTime, Date
@use "../read" readEDN

testset("primitives") do
  @test readEDN("false") == false
  @test readEDN("true") == true
  @test readEDN("nil") == nothing
  @test readEDN("1") == 1
  @test readEDN("1.1") == 1.1
  @test readEDN("-1.1e3") == -1.1e3
  @test readEDN("\\newline") == '\n'
  @test readEDN("\\c") == 'c'
  @test readEDN("c") == Symbol("c")
  @test readEDN(":c") == Symbol(":c")
  @test readEDN(":c/b") == Symbol(":c/b")
end

testset("strings") do
  @test readEDN("\"hi\"") == "hi"
  @test readEDN("\"\\n\"") == "\n"
  @test readEDN("\"\\u2208\"") == "∈"
end

testset("List") do
  @test readEDN("()") == ()
  @test readEDN("(1)") == (1,)
  @test readEDN("(1 2)") == (1,2)
  @test readEDN("( 1, 2 )") == (1,2)
end

testset("Vector") do
  @test readEDN("[]") == []
  @test readEDN("[1]") == Any[1]
  @test readEDN("[1,2]") == Any[1,2]
  @test readEDN("[ 1, 2 ]") == Any[1,2]
end

testset("Dict") do
  @test readEDN("{}") == Dict()
  @test readEDN("{a 1}") == Dict(:a=>1)
  @test readEDN("{ a 1 }") == Dict(:a=>1)
  @test readEDN("{a 1 b 2}") == Dict(:a=>1,:b=>2)
end

struct A; a;b;c end
testset("tagged literals") do
  @test readEDN("#uuid \"00000000-0000-0000-0000-000000000001\"") == Base.UUID(UInt128(1))
  @test readEDN("#inst \"1985-04-12T23:20:50.52\"") == DateTime(1985,4,12,23,20,50,520)
  @test readEDN("#inst \"1985-04-12\"") == Date(1985,4,12)
  @test readEDN("#{}") == Set()
  @test readEDN("#{1 2}") == Set([1,2])
  @test readEDN("#Rational [1 2]") == 1//2
  @test isa(readEDN("#A (1 2 3)", @__MODULE__), A)
  @test readEDN("#DataType \"Rational{Int64}\"") == Rational{Int64}
end

struct B{t} a end
struct C{t,d} a end

testset("DataTypes") do
  @test readEDN("#Type \"Rational{Int64}\"") == Rational{Int64}
  @test readEDN("#Type \"B{:a}\"", @__MODULE__) == B{:a}
  @test readEDN("#Type \"C{:a,1}\"", @__MODULE__) == C{:a,1}
end
