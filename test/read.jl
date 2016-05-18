@require "../read" readEDN

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

test("strings") do
  @test readEDN("\"hi\"") == "hi"
  @test readEDN("\"\\n\"") == "\n"
  @test readEDN("\"\\u2208\"") == "∈"
end

test("List") do
  @test readEDN("()") == ()
  @test readEDN("(1)") == (1,)
  @test readEDN("(1 2)") == (1,2)
  @test readEDN("( 1, 2 )") == (1,2)
end

test("Vector") do
  @test readEDN("[]") == []
  @test readEDN("[1]") == Any[1]
  @test readEDN("[1,2]") == Any[1,2]
  @test readEDN("[ 1, 2 ]") == Any[1,2]
end

test("Dict") do
  @test readEDN("{}") == Dict()
  @test readEDN("{a 1}") == Dict(:a=>1)
  @test readEDN("{ a 1 }") == Dict(:a=>1)
  @test readEDN("{a 1 b 2}") == Dict(:a=>1,:b=>2)
end

test("tagged literals") do
  @test readEDN("#uuid \"00000000-0000-0000-0000-000000000001\"") == Base.Random.UUID(UInt128(1))
  @test readEDN("#inst \"1985-04-12T23:20:50.52\"") == DateTime(1985,4,12,23,20,50,520)
  @test readEDN("#inst \"1985-04-12\"") == Date(1985,4,12)
  @test readEDN("#{}") == Set()
  @test readEDN("#{1 2}") == Set([1,2])
  @test readEDN("#Rational [1 2]") == 1//2
  @test readEDN("#Nullable{Int64} [1]") |> get == 1
  @test isa(readEDN("#Base.Test.Success (1 2 true)"), Base.Test.Success)
end
