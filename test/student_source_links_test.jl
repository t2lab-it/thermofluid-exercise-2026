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
    # Explanatory N01 links select the namespace; split-source Elliptic links
    # identify the module declaration, even though both sources contain a body.
    module_source = "module N01\none(x)=x\nend\n"
    check_module(label, path, fragment, source) = StudentSourceLinks.check_links(
        link(label, fragment; path), "fixture.qmd", (ref, path) -> source)
    @test isempty(check_module("N01", "src/ThermofluidExercise.jl", "#L1-L3", module_source))
    @test !isempty(check_module("N01", "src/ThermofluidExercise.jl", "#L1", module_source))
    elliptic_source = replace(module_source, "N01" => "Elliptic")
    @test isempty(check_module("ThermofluidExercise.Elliptic", "src/N08N09Elliptic.jl", "#L1", elliptic_source))
    @test !isempty(check_module("ThermofluidExercise.Elliptic", "src/N08N09Elliptic.jl", "#L1-L3", elliptic_source))
    # Module context resolves unqualified names independently of the URL range.
    contextual = link("A", "#L1-L13") * "の" * link("apply_boundary!", "#L6-L10")
    @test isempty(check(contextual))
    @test !isempty(check(replace(contextual, "#L6-L10" => "#L15-L17")))
    @test !isempty(check("[unlabelled]($base/blob/main/src/example.jl#L12)"))
    # Special references express existing page intent, not a filename suffix guess.
    aliaspath = "exercises/N05-N06_common_package_2d_advection/N05.jl"
    aliastext = link("N05.jl verify", "#L2-L4"; path=aliaspath)
    aliassource = "module N05Regression\nfunction verify(x)\nx\nend\nend\n"
    @test isempty(StudentSourceLinks.check_links(aliastext, "guides/workflow.qmd", (ref, path) -> aliassource))
    @test !isempty(StudentSourceLinks.check_links(aliastext, "other.qmd", (ref, path) -> aliassource))
    @test !isempty(StudentSourceLinks.check_links(link("one", "#L1"), "broken.qmd",
                                                  (ref, path) -> "one(x)=x\nfunction broken(\n"))
    @test !isempty(check("<$base#unsupported>"))
    @test isempty(StudentSourceLinks.source_links(replace(link("one", "#L12"), "github.com" => "githubXcom")))
end

@testset "offline Git snapshot and public render scope" begin
    mktempdir() do root
        student = joinpath(root, "student")
        public = joinpath(root, "public")
        mkpath(joinpath(student, "src")); mkpath(joinpath(public, "pages")); mkpath(joinpath(public, "private"))
        run(pipeline(`git -C $student init --quiet`, stdout=devnull))
        # A fixed Git snapshot is valid to parse but must never be executed.
        # The checkout deliberately disagrees, so reading it instead also fails.
        source = "one(x)=x\nerror(\"student source must not be executed\")\n"
        student_path = joinpath(student, "src", "one.jl")
        write(student_path, "error(\"working copy must not be read\")\n")
        blob = strip(read(pipeline(`git -C $student hash-object -w --stdin`, stdin=IOBuffer(source)), String))
        src_tree = strip(read(pipeline(`git -C $student mktree`, stdin=IOBuffer("100644 blob $blob\tone.jl\n")), String))
        tree = strip(read(pipeline(`git -C $student mktree`, stdin=IOBuffer("040000 tree $src_tree\tsrc\n")), String))
        sha = strip(read(pipeline(`git -C $student -c user.name=Fixture -c user.email=fixture@example.invalid commit-tree $tree`,
                                 stdin=IOBuffer("fixture\n")), String))
        base = StudentSourceLinks.BASE
        write(joinpath(public, "_quarto.yml"), "project:\n  render:\n    - pages/*.qmd\n")
        url = "$base/blob/main/src/one.jl#L1"
        page = joinpath(public, "pages", "one.qmd")
        valid = "[`one(x)`]($url)\n[file]($base/blob/main/src/one.jl)\n[dir]($base/tree/main/src)\n<$base>"
        write(page, valid)
        missing = "[missing]($base/blob/main/src/missing.jl)"
        write(joinpath(public, "pages", "_partial.qmd"), missing)
        write(joinpath(public, "private", "bad.qmd"), missing)
        inputs = (student_path, page, joinpath(public, "_quarto.yml"),
                  joinpath(public, "pages", "_partial.qmd"), joinpath(public, "private", "bad.qmd"))
        snapshot() = Dict(path => read(path) for path in inputs)
        @test StudentSourceLinks.public_pages(public) == ["pages/one.qmd"]
        report = StudentSourceLinks.audit(student, public, sha)
        @test isempty(report.errors)
        @test length(report.links) == 4 # Signature-labelled function, file, directory, repository.
        @test report.revision == sha
        @test !isempty(StudentSourceLinks.audit(student, public, repeat("f", 40)).errors)
        @test !isempty(StudentSourceLinks.audit(student, public, "--help").errors)
        write(page, missing)
        @test !isempty(StudentSourceLinks.audit(student, public, sha).errors)
        # Check a real blob/tree mismatch, including the actionable diagnostic.
        wrong_kind = "$base/blob/main/src"
        write(page, "[directory]($wrong_kind)")
        errors = StudentSourceLinks.audit(student, public, sha).errors
        @test length(errors) == 1 && startswith(only(errors), "pages/one.qmd:1: $wrong_kind:") &&
              occursin("Git object kind mismatch", only(errors))
        write(page, replace(valid, "#L1" => "#L99"))
        before = snapshot()
        script = joinpath(@__DIR__, "..", "scripts", "verify_student_source_links.jl")
        cli(args) = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --project=$(@__DIR__)/.. $script $args`),
                                stdout=devnull, stderr=devnull)).exitcode
        # Only one subprocess for each documented exit code. Alternate argument
        # validation runs directly; snapshot guards precede restoring the fixture.
        @test cli([student, public, "--bad", sha]) == 2
        redirect_stderr(devnull) do
            @test StudentSourceLinks.main(String[]) == 2
        end
        @test cli([student, public, "--student-revision", sha]) == 1
        @test snapshot() == before
        write(page, valid)
        before = snapshot()
        @test cli([student, public, "--student-revision", sha]) == 0
        @test snapshot() == before
    end
end
