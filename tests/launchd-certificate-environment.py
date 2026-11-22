import json
import plistlib
import subprocess
import sys


def check_case(case, inherited):
    job = plistlib.loads(case["plist"].encode())
    environment = inherited | job.get("EnvironmentVariables", {})
    expected = inherited | case["expectedEnvironment"]

    if "NIX_SSL_CERT_FILE" not in expected and "SSL_CERT_FILE" not in expected:
        expected["NIX_SSL_CERT_FILE"] = case["defaultBundle"]

    # Execute the plist's command with launchd's environment and argv semantics,
    # without loading a job or changing any running services.
    arguments = job["ProgramArguments"]
    with subprocess.Popen(
        arguments,
        executable=job.get("Program", arguments[0]),
        env=environment,
        stdout=subprocess.PIPE,
    ) as process:
        output, _ = process.communicate(timeout=30)
        assert process.returncode == 23, (
            f"{case['name']}: expected exit status 23, got {process.returncode}"
        )

    fields = output.decode().split("\0")
    expected_fields = [str(process.pid), *case["expectedArgv"]]

    for name in ("NIX_SSL_CERT_FILE", "SSL_CERT_FILE"):
        expected_fields.append(f"{name}={expected[name]}" if name in expected else name)

    # Splitting the probe's trailing NUL produces one final empty field.
    expected_fields.append("")
    assert fields == expected_fields, (
        f"{case['name']} with inherited environment {inherited!r}:\n"
        f"expected: {expected_fields!r}\n"
        f"actual:   {fields!r}"
    )


def main():
    with open(sys.argv[1]) as source:
        cases = json.load(source)

    inherited_environments = [
        {},
        {"NIX_SSL_CERT_FILE": "/inherited/nix.pem"},
        {"SSL_CERT_FILE": "/inherited/ssl.pem"},
        {"NIX_SSL_CERT_FILE": ""},
        {"SSL_CERT_FILE": ""},
        {"NIX_SSL_CERT_FILE": "/inherited/nix.pem", "SSL_CERT_FILE": "/inherited/ssl.pem"},
    ]

    for case in cases:
        for inherited in inherited_environments:
            check_case(case, inherited)

    print(f"Checked {len(cases) * len(inherited_environments)} launchd certificate cases")


if __name__ == "__main__":
    main()
