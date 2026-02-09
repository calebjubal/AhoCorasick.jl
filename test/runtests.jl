using AhoCorasick
using Test

@testset "AhoCorasick.jl" begin
    
    @testset "Basic functionality" begin
        # Classic example from Wikipedia
        automaton = ACAutomaton(["a", "ab", "bab", "bc", "bca", "c", "caa"])
        matches = search(automaton, "abccab")
        
        @test length(matches) > 0
        @test any(m -> m.pattern == "a" && m.start == 1, matches)
        @test any(m -> m.pattern == "ab" && m.start == 1, matches)
        @test any(m -> m.pattern == "bc" && m.start == 2, matches)
        @test any(m -> m.pattern == "c" && m.start == 3, matches)
        @test any(m -> m.pattern == "c" && m.start == 4, matches)
    end
    
    @testset "She/He/His/Hers example" begin
        automaton = ACAutomaton(["he", "she", "his", "hers"])
        matches = search(automaton, "ushers")
        
        # Should find: "she" at 2, "he" at 3, "hers" at 3
        @test length(matches) == 3
        @test any(m -> m.pattern == "she" && m.start == 2 && m.stop == 4, matches)
        @test any(m -> m.pattern == "he" && m.start == 3 && m.stop == 4, matches)
        @test any(m -> m.pattern == "hers" && m.start == 3 && m.stop == 6, matches)
    end
    
    @testset "Single pattern" begin
        automaton = ACAutomaton(["test"])
        matches = search(automaton, "this is a test string with test")
        
        @test length(matches) == 2
        @test matches[1].start == 11
        @test matches[2].start == 28
    end
    
    @testset "Overlapping patterns" begin
        automaton = ACAutomaton(["a", "aa", "aaa"])
        matches = search(automaton, "aaaa")
        
        # Should find all overlapping matches
        @test length(matches) >= 4  # At least 4 single 'a' matches
        @test any(m -> m.pattern == "aaa", matches)
        @test any(m -> m.pattern == "aa", matches)
    end
    
    @testset "No matches" begin
        automaton = ACAutomaton(["xyz", "abc"])
        matches = search(automaton, "hello world")
        
        @test isempty(matches)
    end
    
    @testset "Empty text" begin
        automaton = ACAutomaton(["test"])
        matches = search(automaton, "")
        
        @test isempty(matches)
    end
    
    @testset "Pattern at boundaries" begin
        automaton = ACAutomaton(["start", "end"])
        matches = search(automaton, "start middle end")
        
        @test length(matches) == 2
        @test matches[1].pattern == "start"
        @test matches[1].start == 1
        @test matches[2].pattern == "end"
        @test matches[2].start == 14
    end
    
    @testset "Case sensitivity" begin
        automaton = ACAutomaton(["Test", "TEST", "test"])
        matches = search(automaton, "Test TEST test")
        
        @test length(matches) == 3
        @test matches[1].pattern == "Test"
        @test matches[2].pattern == "TEST"
        @test matches[3].pattern == "test"
    end
    
    @testset "Unicode patterns" begin
        automaton = ACAutomaton(["héllo", "wörld", "日本"])
        
        matches = search(automaton, "héllo wörld")
        @test length(matches) == 2
        @test matches[1].pattern == "héllo"
        @test matches[2].pattern == "wörld"
        
        matches2 = search(automaton, "日本語")
        @test length(matches2) == 1
        @test matches2[1].pattern == "日本"
    end
    
    @testset "Iterator interface" begin
        automaton = ACAutomaton(["he", "she", "hers"])
        text = "ushers"
        
        # Collect matches via iterator
        iter_matches = collect(eachmatch(automaton, text))
        search_matches = search(automaton, text)
        
        # Both should find the same matches (order may differ for iterator)
        @test length(iter_matches) == length(search_matches)
        @test Set(m.pattern for m in iter_matches) == Set(m.pattern for m in search_matches)
    end
    
    @testset "ACMatch properties" begin
        automaton = ACAutomaton(["test"])
        matches = search(automaton, "a test here")
        
        @test length(matches) == 1
        m = matches[1]
        @test m.pattern == "test"
        @test m.pattern_index == 1
        @test m.start == 3
        @test m.stop == 6
    end
    
    @testset "Multiple occurrences" begin
        automaton = ACAutomaton(["na"])
        matches = search(automaton, "banana")
        
        @test length(matches) == 2
        @test matches[1].start == 3
        @test matches[2].start == 5
    end
    
    @testset "Prefix patterns" begin
        automaton = ACAutomaton(["pre", "prefix", "prefixation"])
        matches = search(automaton, "prefixation")
        
        @test length(matches) == 3
        @test all(m -> m.start == 1, matches)  # All start at position 1
    end
    
    @testset "Suffix patterns" begin
        automaton = ACAutomaton(["tion", "ation", "ization"])
        matches = search(automaton, "optimization")
        
        @test length(matches) == 3
        @test any(m -> m.pattern == "tion", matches)
        @test any(m -> m.pattern == "ation", matches)
        @test any(m -> m.pattern == "ization", matches)
    end
    
    @testset "Large number of patterns" begin
        # Generate many patterns
        patterns = ["pattern$i" for i in 1:100]
        automaton = ACAutomaton(patterns)
        
        text = join(patterns[1:10], " ")
        matches = search(automaton, text)
        
        # Note: "pattern1" is prefix of "pattern10", so we get 11 matches
        @test length(matches) == 11
    end
    
    @testset "String type flexibility" begin
        # SubString
        patterns = [SubString("hello", 1, 3), SubString("world", 1, 4)]
        automaton = ACAutomaton(patterns)
        matches = search(automaton, "hel worl")
        
        @test length(matches) == 2
    end
    
end
