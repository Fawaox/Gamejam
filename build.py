import subprocess
import sys

PACKAGE = "Game"


def main():
    if len(sys.argv) != 3:
        print("Usage: python build.py [build|run] [debug|release]")
        return

    command = sys.argv[1]
    mode = sys.argv[2]

    if command not in ["build", "run"]:
        print("Error: First argument must be 'build' or 'run'")
        return

    if mode not in ["debug", "release"]:
        print("Error: Second argument must be 'debug' or 'release'")
        return

    cmd = ["odin", command, PACKAGE]

    if mode == "release":
        cmd.append("-o:speed")

    print("Running:", " ".join(cmd))
    subprocess.run(cmd)


if __name__ == "__main__":
    main()
