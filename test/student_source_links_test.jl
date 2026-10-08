using Test

if !isdefined(@__MODULE__, :StudentSourceLinks)
    include(joinpath(@__DIR__, "..", "scripts", "verify_student_source_links.jl"))
end

@testset "student source selection contracts (parse only)" begin
    base = StudentSourceLinks.BASE
    link(label, fragment; path="src/example.jl", kind="blob", ref="main") =
        "[`$label`]($base/$kind/$ref/$path$fragment)"
    # A docstring contains a plausible definition; it must never be selectable.
    source = join(("module A", "\"\"\"", "function fake(x)", "end", "\"\"\"",
                   "function apply_boundary!(x)", "    if x > 0", "        x", "    end", "end",
                   "const C = 1", "one(x)=x", "end", "module B",
                   "function apply_boundary!(x)", "    x", "end", "end"), '\n') * "\n"
    reader = (ref, path) -> source
    check(text; kwargs...) = StudentSourceLinks.check_links(text, "fixture.qmd", reader; kwargs...)
    @test isempty(check(link("A.apply_boundary!(x)", "#L6-L10")))
    @test isempty(check(link("one", "#L12")))
    @test isempty(check(link("C", "#L11")))
    @test isempty(check(link("A", "#L1-L13")))
    @test isempty(check(link("A", "#L1")))
    @test !isempty(check(link("A.apply_boundary!", "#L6-L9")))
    @test !isempty(check(link("A.apply_boundary!", "#L6-L11")))
    @test !isempty(check(link("A.apply_boundary!", "#L6")))
    @test !isempty(check(link("A.apply_boundary!", "#L15-L17")))
    @test !isempty(check(link("apply_boundary!", "#L6-L10"))) # ambiguous namespace
    @test !isempty(check(link("fake", "#L3-L4")))
    @test !isempty(check(link("A.apply_boundary!", "#L2-L10"))) # docstring included
    @test !isempty(check(link("one", "#L99")))
    @test !isempty(check(link("one", "#L12-L11")))
    @test !isempty(check(link("one", "#L12-L12"))) # canonical single-line URL
    @test !isempty(check(link("one", "#foo")))
    @test !isempty(check(link("one", "#L12"; ref=repeat("a", 40))))
    @test !isempty(check(link("one", "#L12"); read_kind=(ref, path) -> "tree"))
    @test !isempty(StudentSourceLinks.check_links(link("one", "#L12"), "fixture.qmd",
                                                  (ref, path) -> error("missing Git object")))
    @test isempty(check("[file]($base/blob/main/src/example.jl)\n[dir]($base/tree/main/src)\n<$base>";
                        read_kind=(ref, path) -> path == "src" ? "tree" : "blob"))
    @test !isempty(check("[dir]($base/tree/main/src)"; read_kind=(ref, path) -> "blob"))
    @test !isempty(check("[file]($base/blob/main/missing)";
                         read_kind=(ref, path) -> error("missing Git object")))
    # Module context resolves unqualified names independently of the URL range.
    contextual = link("A", "#L1-L13") * "の" * link("apply_boundary!", "#L6-L10")
    @test isempty(check(contextual))
    @test !isempty(check(replace(contextual, "#L6-L10" => "#L15-L17")))
    @test length(StudentSourceLinks.source_links(link("one(x)", "#L12"))) == 1
    @test only(StudentSourceLinks.source_links(link("one(x)", "#L12"))).label == "`one(x)`"
    @test !isempty(check("[unlabelled]($base/blob/main/src/example.jl#L12)"))
    # Special references express existing page intent, not a filename suffix guess.
    aliaspath = "exercises/N05-N06_common_package_2d_advection/N05.jl"
    aliastext = link("N05.jl verify", "#L2-L4"; path=aliaspath)
    aliassource = "module N05Regression\nfunction verify(x)\nx\nend\nend\n"
    @test isempty(StudentSourceLinks.check_links(aliastext, "guides/workflow.qmd", (ref, path) -> aliassource))
    @test !isempty(StudentSourceLinks.check_links(aliastext, "other.qmd", (ref, path) -> aliassource))
    @test !isempty(check(link("one", "#L12"); read_kind=(ref, path) -> "commit"))
    @test !isempty(StudentSourceLinks.check_links(link("one", "#L1"), "broken.qmd",
                                                  (ref, path) -> "function one(\n"))
    @test !isempty(StudentSourceLinks.check_links(link("one", "#L1"), "broken.qmd",
                                                  (ref, path) -> "one(x)=x\nfunction broken(\n"))
    @test !isempty(check("<$base#unsupported>"))
    @test isempty(StudentSourceLinks.source_links(replace(link("one", "#L12"), "github.com" => "githubXcom")))
end

@testset "offline Git snapshot and public render scope" begin
    mktempdir() do root
        student = joinpath(root, "student")
        public = joinpath(root, "public")
        mkpath(student); mkpath(joinpath(public, "pages")); mkpath(joinpath(public, "private"))
        run(pipeline(`git -C $student init --quiet`, stdout=devnull))
        # Build synthetic Git objects without changing a real repository's history.
        source = "one(x)=x\n"
        blob = strip(read(pipeline(`git -C $student hash-object -w --stdin`, stdin=IOBuffer(source)), String))
        tree = strip(read(pipeline(`git -C $student mktree`, stdin=IOBuffer("100644 blob $blob\tone.jl\n")), String))
        sha = strip(read(pipeline(`git -C $student -c user.name=Fixture -c user.email=fixture@example.invalid commit-tree $tree`,
                                 stdin=IOBuffer("fixture\n")), String))
        write(joinpath(public, "_quarto.yml"), "project:\n  render:\n    - pages/*.qmd\n")
        url = "$(StudentSourceLinks.BASE)/blob/main/one.jl#L1"
        write(joinpath(public, "pages", "one.qmd"), "[`one`]($url)")
        write(joinpath(public, "pages", "_partial.qmd"), "ignored")
        write(joinpath(public, "private", "bad.qmd"), "[bad]($(StudentSourceLinks.BASE)/blob/main/missing)")
        @test StudentSourceLinks.public_pages(public) == ["pages/one.qmd"]
        report = StudentSourceLinks.audit(student, public, sha)
        @test isempty(report.errors)
        @test length(report.links) == 1
        @test report.revision == sha
        @test !isempty(StudentSourceLinks.audit(student, public, repeat("f", 40)).errors)
        @test !isempty(StudentSourceLinks.audit(student, public, "--help").errors)
        write(joinpath(public, "pages", "one.qmd"), "[`one`]($(replace(url, "#L1" => "#L2")))")
        @test !isempty(StudentSourceLinks.audit(student, public, sha).errors)
        script = joinpath(@__DIR__, "..", "scripts", "verify_student_source_links.jl")
        cli(args) = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --project=$(@__DIR__)/.. $script $args`),
                                stdout=devnull, stderr=devnull)).exitcode
        @test cli(String[]) == 2
        @test cli([student, public, "--bad", sha]) == 2
        @test cli([student, public, "--student-revision", sha]) == 1
        write(joinpath(public, "pages", "one.qmd"), "[`one`]($url)")
        @test cli([student, public, "--student-revision", sha]) == 0
        @test cli([student, public, "--student-revision", repeat("f", 40)]) == 1
        @test read(joinpath(public, "pages", "one.qmd"), String) == "[`one`]($url)"
    end
end
