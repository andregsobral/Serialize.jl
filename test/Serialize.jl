using Serialize

@serialize Client
@serialize Person
@serialize Department
@serialize Car
@serialize Cat
@serialize AType
@serialize OtherType
@serialize FourthType
@serialize Company
@serialize GenVec
@serialize GenVecU
@serialize GenDict
@serialize GenDictU
@serialize DictWrapper
@serialize HelloGen
@serialize VecWrapper
# @serialize All


@testset "Serialization tests       " begin

    @testset "Serialize VecWrapper" begin
        vw = VecWrapper([1,2,"3", AType("Hello")])
        vw_bson = Mongoc.BSON(vw)
        # @show VecWrapper(Mongoc.BSON(vw))

        @test vw_bson["attr"][1] == vw.attr[1]
        @test vw_bson["attr"][2] == vw.attr[2]
        @test vw_bson["attr"][3] == vw.attr[3]
        @test vw_bson["attr"][4]["attr"]  == vw.attr[4].attr
        @test haskey(vw_bson["attr"][4], "_type") == true
        @test vw_bson["attr"][4]["_type"] == string(typeof(vw.attr[4]))

        vw = VecWrapper([[1,2,"3"],[4,5,6]])
        vw_bson = Mongoc.BSON(vw)
        for i in 1:length(vw_bson["attr"])
            @test vw_bson["attr"][i] == vw.attr[i]
        end
        
        # --- ToDo: Recursive calls
        # vw = VecWrapper([[1,2,"3"], [AType("Hello"),"3"]])
        # @show Mongoc.BSON(vw)
        # @show VecWrapper(Mongoc.BSON(vw))
    end

    @testset "Primitive serialization" begin
        # --- Examples for a struct with only primitive values (+ DateTime)
        cat      = Cat("Yuki", 3, 98.5, Dates.now())
        cat_bson = Mongoc.BSON(cat)
        @test cat_bson["name"]          == cat.name          # String
        @test cat_bson["age"]           == cat.age           # Int
        @test cat_bson["height"]        == cat.height        # Float
        @test cat_bson["date_of_birth"] == cat.date_of_birth # DateTime
        @test haskey(cat_bson, "_type") == false

        # --- Another test
        atype = AType(Faker.text(number_chars=10))
        atype_bson = Mongoc.BSON(atype)
        @test haskey(atype_bson, "attr")  == true
        @test atype_bson["attr"] == atype.attr
        @test haskey(atype_bson, "_type") == false

        # --- Another test
        otype = OtherType(parse(Int, Faker.random_int(min=0, max=9999)))
        otype_bson = Mongoc.BSON(atype)
        @test haskey(otype_bson, "attr")  == true
        @test otype_bson["attr"] == atype.attr
        @test haskey(otype_bson, "_type") == false
    end


    @testset "Union serialization" begin
        # --- Union{Int, String}: Union of basic types, shouldnt have _type
        car = Car("Mazerati")
        car_bson = Mongoc.BSON(car)
        @test haskey(car_bson, "brand") == true
        @test car_bson["brand"] == car.brand
        @test haskey(car_bson, "_type") == false

        # --- Union{Int, String}: Union of basic types, shouldnt have _type
        car = Car(10000)
        car_bson = Mongoc.BSON(car)
        @test haskey(car_bson, "brand") == true
        @test car_bson["brand"] == car.brand
        @test haskey(car_bson, "_type") == false

        # --- Union{Atype, OtherType}: Union of composite type, should have _type
        fourthtype = FourthType(AType(Faker.text(number_chars=10)))
        fourthtype_bson = Mongoc.BSON(fourthtype)
        @test haskey(fourthtype_bson, "attr")          == true
        @test haskey(fourthtype_bson["attr"], "attr")  == true
        @test fourthtype_bson["attr"]["attr"]          == fourthtype.attr.attr
        @test haskey(fourthtype_bson["attr"], "_type") == true
        @test fourthtype_bson["attr"]["_type"]         == "AType"

        # --- Union{Atype, OtherType}: Union of composite type, should have _type
        fourthtype = FourthType(OtherType(parse(Int, Faker.random_int(min=0, max=9999))))
        fourthtype_bson = Mongoc.BSON(fourthtype)
        @test haskey(fourthtype_bson, "attr")          == true
        @test haskey(fourthtype_bson["attr"], "attr")  == true
        @test fourthtype_bson["attr"]["attr"]          == fourthtype.attr.attr
        @test haskey(fourthtype_bson["attr"], "_type") == true
        @test fourthtype_bson["attr"]["_type"]         == "OtherType"
    end


    @testset "Array serialization" begin
        # --- A struct that holds primitive and other user-defined types
        c = Client("Andre", 100, 1.5, Department("RAS"), [Car("Mazda"), Car("Ford")])
        bson = Mongoc.BSON(c)
        @test bson["name"] == c.name
        @test bson["id"]   == c.id
        @test bson["tier"] == c.tier
        @test bson["dep"]["name"]  == c.dep.name
        # --- Vector{Car}: A struct that holds a vector of a concrete type
        for i in 1:length(c.cars)
            @test bson["cars"][i]["brand"] == c.cars[i].brand
            @test haskey(bson["cars"][i], "_type") == false
        end

        # --- Vector{GenericType}: A struct that holds a vector of an abstract type
        genvec      = GenVec([AType(Faker.text(number_chars=10)), OtherType(parse(Int, Faker.random_int(min=0, max=9999)))])
        genvec_bson = Mongoc.BSON(genvec)
        @test haskey(genvec_bson, "attr")  == true
        @test length(genvec_bson["attr"])  == 2
        # TODO: write function to add random AType and OtherType to genvec and use "for" loop
        @test genvec_bson["attr"][1]["attr"]          == genvec.attr[1].attr
        @test haskey(genvec_bson["attr"][1], "_type") == true
        @test genvec_bson["attr"][1]["_type"]         == "AType"
        
        @test genvec_bson["attr"][2]["attr"]          == genvec.attr[2].attr
        @test haskey(genvec_bson["attr"][2], "_type") == true
        @test genvec_bson["attr"][2]["_type"]         == "OtherType"
    end

    @testset "Dict serialization" begin
        # --- Dict{String, Client}: A struct that holds a Dict of a concrete type
        c = Client("Andre", 100, 1.5, Department("RAS"), [Car("Mazda"), Car("Ford")])
        p = Person(Dict("Andre" => c), Dict("tall" => 190), Dict("toys" => "car"))
        bson = Mongoc.BSON(p)
        
        bson_c = bson["name"]["Andre"] 
        @test haskey(bson["name"], "_type") == false  
        @test bson_c["name"] == c.name
        @test bson_c["id"]   == c.id
        @test bson_c["tier"] == c.tier
        @test bson_c["dep"]["name"]  == c.dep.name
        for i in 1:length(c.cars)
            @test bson_c["cars"][i]["brand"] == c.cars[i].brand
        end
        @test bson["height"] == p.height
        @test bson["items"]  == p.items

        # --- Dict{String, GenericType}: A struct that holds a Dict of an abstract type
        gendict = GenDict(Dict("1" => AType(Faker.text(number_chars=10)), "2" => OtherType(parse(Int, Faker.random_int(min=0, max=9999)))))
        gendict = GenDict(Dict("1" => AType(Faker.text(number_chars=10)), "2" => OtherType(parse(Int, Faker.random_int(min=0, max=9999)))))
        gendict_bson = Mongoc.BSON(gendict)
        @test haskey(gendict_bson, "attr")  == true
        # TODO: write function to add random AType and OtherType to genvec and use "for" loop
        @test gendict_bson["attr"]["1"]["attr"]          == gendict.attr["1"].attr
        @test haskey(gendict_bson["attr"]["1"], "_type") == true
        @test gendict_bson["attr"]["1"]["_type"]         == "AType"

        @test gendict_bson["attr"]["2"]["attr"]          == gendict.attr["2"].attr
        @test haskey(gendict_bson["attr"]["2"], "_type") == true
        @test gendict_bson["attr"]["2"]["_type"]         == "OtherType"
    end
end

@testset "Deserialization tests     " begin

    @testset "Primitive deserialization" begin
        # --- A BSON that holds a struct with only primitive values (+ DateTime)
        cat_bson = Mongoc.BSON("""{ "name" : "Yuki", "age" : 3, "height" : 98.5, "date_of_birth" : { "\$date" : "2021-09-18T19:49:58.870Z" } }""")
        cat = Cat(cat_bson)
        @test cat.name          == cat_bson["name"]          
        @test cat.age           == cat_bson["age"]           
        @test cat.height        == cat_bson["height"]        
        @test cat.date_of_birth == cat_bson["date_of_birth"]
    end

    @testset "Union deserialization" begin
        # --- A BSON that holds a struct with Union values in fields
        car_bson = Mongoc.BSON("brand" => "Mazerati")
        car = Car(car_bson)
        @test car_bson["brand"] == car.brand
        car_bson = Mongoc.BSON("brand" => 10000)
        car = Car(car_bson)
        @test car_bson["brand"] == car.brand
    end

    @testset "Composite deserialization" begin
        # --- A BSON that holds a struct with other user-defined types
        bson = Mongoc.BSON("name" => "Andre", "id" => 100, "tier" => 1.5, "dep" => Dict("name" => "RAS"), "cars" => [Dict("brand" => "Mazda"), Dict("brand" => "Ford")] )
        c = Client(bson)
        @test c.name     == bson["name"] 
        @test c.id       == bson["id"]
        @test c.tier     == bson["tier"]
        @test c.dep.name == bson["dep"]["name"]
        for i in 1:length(bson["cars"])
            @test c.cars[i].brand == bson["cars"][i]["brand"] 
        end
    end

    @testset "Composition deserialization" begin
        # --- A BSON that holds a struct with primitive types, user-defined types and Dict fields
        bson_person = Mongoc.BSON(
            "name" => Dict("Andre" => 
                Dict("name" => "Andre", 
                    "id"    => 100, 
                    "tier"  => 1.5, 
                    "dep"   => Dict("name" => "RAS"), 
                    "cars"  => [Dict("brand" => "Mazda"), Dict("brand" => "Ford")])),
            "height" => Dict("tall" => 190),
            "items"  => Dict("toys" => "car")
        )

        p = Person(bson_person)

        c = p.name["Andre"]
        bson_client = bson_person["name"]["Andre"]
        @test c.name     == bson_client["name"]
        @test c.id       == bson_client["id"]
        @test c.tier     == bson_client["tier"]
        @test c.dep.name == bson_client["dep"]["name"]
        for i in 1:length(bson_client["cars"])
            @test c.cars[i].brand == bson_client["cars"][i]["brand"] 
        end
        @test p.height == bson_person["height"]
        @test p.items  == bson_person["items"]
    end

    @testset "Most cases of deserialization" begin
        at = AType("hello")
        ot = OtherType(1)
        ft = FourthType(ot)
        c  = Company(Dict("testing" => ot))
        gv = GenVec([at,at,ot])
        gvu = GenVecU([at,ot,ot])
        gd  = GenDict(Dict("1" => at, "2" => ot))
        gdu = GenDictU(Dict("1" => at, "2" => c))
        hg = HelloGen(gv.attr, gvu.attr, ["testing"], AType("12"), OtherType(12), AType("12"), Dict("one" => at), Dict("one" => at), Dict("one" => at), Dict("wut" => 123), Dict{Any, Any}("String" => 12312, "dasdas" => AType("12")), "test", 100)
        dwr = DictWrapper(Dict{Any, Any}("String" => 12312, "dasdas" => AType("12")))

        @test AType(Mongoc.BSON(at)).attr      == at.attr
        @test OtherType(Mongoc.BSON(ot)).attr  == ot.attr
        @test FourthType(Mongoc.BSON(ft)).attr == ft.attr
        @test Company(Mongoc.BSON(c)).attr     == c.attr
        @test GenVec(Mongoc.BSON(gv)).attr     == gv.attr
        @test GenDict(Mongoc.BSON(gd)).attr    == gd.attr
        @test GenDictU(Mongoc.BSON(gdu)).attr["1"]       == gdu.attr["1"]
        @test GenDictU(Mongoc.BSON(gdu)).attr["2"].attr  == gdu.attr["2"].attr
        @test DictWrapper(Mongoc.BSON(dwr)).attr  == dwr.attr
        

        res = HelloGen(Mongoc.BSON(hg))
        for f in fieldnames(HelloGen)
            @test getfield(res, f) == getfield(hg, f)
        end
    end

    @testset "Deserialize VecWrapper" begin
        vw  = VecWrapper([1,2,"3", AType("Hello")])
        vvw = VecWrapper(Mongoc.BSON(vw))
        for i in 1:length(vw.attr)
            @test vw.attr[i] == vvw.attr[i]
        end

        vw = VecWrapper([[1,2,"3"],[4,5,6]])
        vvw = VecWrapper(Mongoc.BSON(vw))
        for i in 1:length(vw.attr)
            @test vvw.attr[i] == vw.attr[i]
        end
    end
end

# function profiling()
#     println("----- Performance Serialize------")    
#     c1 = Client("Andre", 100, 1.5, Department("RAS"), [Car("Mazda"), Car("Ford")])
#     c2 = Client("Luis", 100, 1.5, Department("RAS"), [Car("Mazda"), Car("Ford")])
#     p = Person(Dict("test" => c1))
#     car = Car("hello")
#     @time Car("hello") # -- for time to compile timing functions
#     println("----- [Serialization] Client - 1st Execution ------")    
#     @time c1_bson  = Mongoc.BSON(c1)
#     @time c2_bson  = Mongoc.BSON(c2)
#     # println("----- [Serialization] Person - 1st Execution ------")       
#     # @time p_bson  = Mongoc.BSON(p)
#     # @time p_bson  = Mongoc.BSON(p)
#     println("----- [Serialization] Car - 1st Execution ------")       
#     @time car_bson  = Mongoc.BSON(car)
#     @time car_bson  = Mongoc.BSON(car)
#     println("----- [Deserialization] Client - 1st Execution ------")       
#     @time c1_deser = Client(c1_bson)
#     @time c2_deser = Client(c2_bson)
#     # println("----- [Deserialization] Person - 1st Execution ------")      
#     # @time p_deser = Person(p_bson)
#     # @time p_deser = Person(p_bson)
#     println("----- [Deserialization] Car - 1st Execution ------")      
#     @time car_deser = Car(car_bson)
#     @time car_deser = Car(car_bson)

#     println("----------------------")
# end
# profiling()

