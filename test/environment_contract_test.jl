using Test

const ENVIRONMENT_CONTRACT_ROOT = normpath(joinpath(@__DIR__, ".."))

read_environment(relative) =
    read(joinpath(ENVIRONMENT_CONTRACT_ROOT, relative), String)

@testset "WSL2 and native Unix environment contract" begin
    setup = read_environment("setup/index.qmd")
    julia_setup = read_environment("setup/julia.qmd")
    agents = read_environment("setup/agents.qmd")
    git_setup = read_environment("setup/git-github.qmd")
    ssh = read_environment("advanced/github-ssh.qmd")
    cli = read_environment("advanced/github-cli.qmd")
    f00 = read_environment("assignments/F00.qmd")
    troubleshooting = read_environment("guides/troubleshooting.qmd")

    for term in ("WSL2 Ubuntu 24.04", "native macOS", "native Linux", "/home/<user>")
        @test occursin(term, setup)
    end
    for term in ("WSL1", "Git Bash", "/mnt/c", "Remote - WSL")
        @test occursin(term, setup)
    end
    @test occursin("learn.microsoft.com/en-us/windows/wsl/install", setup)
    @test occursin("code.visualstudio.com/docs/remote/wsl-tutorial", setup)
    @test occursin("SSHで個人課題用リポジトリを複製", setup)

    for source in (setup, julia_setup, agents, git_setup, ssh, cli, f00, troubleshooting)
        @test !occursin("PowerShell", source)
        @test !occursin("winget", source)
    end

    @test occursin("git clone git@github.com:OWNER/REPOSITORY.git", git_setup)
    @test !occursin("YOUR_COURSE_REPOSITORY_URL", git_setup)
    @test !occursin("HTTPS URL", git_setup)
    @test occursin("SSH接続は標準の複製経路", git_setup)

    @test occursin("準備 3/5 の必須手順", ssh)
    @test occursin("### Windows (WSL2 Ubuntu 24.04)", ssh)
    @test occursin("### macOS", ssh)
    @test occursin("### Linux", ssh)
    @test occursin("git remote set-url origin git@github.com:OWNER/REPOSITORY.git", ssh)

    @test occursin("Windows (WSL2 Ubuntu)", cli)
    @test occursin("install_linux.md", cli)

    for term in (
        "runtime（WSL2 / native Linux / macOS）",
        "pwdが正式なworkspace",
        "Remote - WSL",
        "confirm-vscode",
        "confirm-github",
        "confirm-agent",
        "F00 is complete",
        "Current exercise is now F01",
    )
        @test occursin(term, f00)
    end

    for term in ("pwd", "uname -a", "git remote -v", "WSL1", "/mnt/c")
        @test occursin(term, troubleshooting)
    end
end
